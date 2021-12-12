#![allow(dead_code)]
mod misc_error;
mod footprint;
mod minisvg;
mod amcut;
mod poly_utils;

use std::error::Error;
use std::path::{Path,PathBuf};
use std::fs::File;
use std::io::{BufReader,BufRead};
use std::f64::consts::PI;

use log::{error,warn,info};
use chrono::{DateTime,NaiveDate,Utc};
use clap::{Arg,App};
use misc_error::MiscError;
use footprint::{Footprint,Footprints};
use geo::prelude::Contains;
use geo::Point;

struct IASINexIterator {
    buf:BufReader<File>,
    dataset_id:String,
    line:String,
    path:PathBuf,
    row:usize
}

impl IASINexIterator {
    pub fn new<P:AsRef<Path>>(path:P)->Result<Self,Box<dyn Error>> {
	let fd = File::open(&path)?;
	let buf = BufReader::new(fd);

	let mut pb = PathBuf::new();
	pb.push(&path);
	let dataset_id =
	    MiscError::from_option(pb.file_stem(),
				   "Cannot extract dataset name")?
	    .to_string_lossy()
	    .to_string();
	info!("Dataset ID: {:?}",dataset_id);
	Ok(Self{
	    buf,
	    path:pb,
	    dataset_id,
	    line:String::new(),
	    row:0
	})
    }

    fn error(&self,e:Box<dyn Error>)->Option<IASINexRow> {
	error!("Error at row {} in file {:?}: {}",self.row,self.path,e);
	None
    }
}

struct IASINexRow {
    t:f64,
    igra:u32,
    iscan:u32,
    outline:[(f64,f64);4]
}

impl Iterator for IASINexIterator {
    type Item = IASINexRow;

    fn next(&mut self)->Option<Self::Item> {
	self.line.clear();
	match self.buf.read_line(&mut self.line) {
	    Ok(0) => None,
	    Ok(_) => {
		self.row += 1;
		let xs : Vec<&str> = self.line.split_ascii_whitespace().collect();
		if xs.len() != 18 {
		    error!("Invalid number {} of elements in file {:?} line {}",
			   xs.len(),self.path,self.row);
		    return None
		}

		match xs[0..10]
		    .iter()
		    .map(|x| MiscError::convert(x.parse::<i32>(),"Invalid integer"))
		    .collect::<Result<Vec<i32>,_>>() {
			Ok(us) => {
			    match xs[10..]
				.iter()
				.map(|x| MiscError::convert(x.parse::<f64>(),"Invalid float"))
				.collect::<Result<Vec<f64>,_>>() {
				    Ok(fs) => {
					let t_pixel = DateTime::<Utc>::from_utc(
					    NaiveDate::from_ymd(us[2],us[3] as u32,us[4] as u32)
						.and_hms(us[6] as u32,us[7] as u32,us[8] as u32),Utc);
					let t = t_pixel.timestamp_millis() as f64 / 1000.0;
					let igra = us[0] as u32;
					let iscan = us[1] as u32;
					let outline = [(fs[0],fs[4]), (fs[1],fs[5]), (fs[2],fs[6]), (fs[3],fs[7])];
					Some(IASINexRow{ t,
							 igra,
							 iscan,
							 outline})
				    },
				    Err(e) => return self.error(e)
				}
			},
			Err(e) => return self.error(e)
		    }
	    },
	    Err(e) => return self.error(Box::new(e))
	}
    }
}

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;

    let args = App::new("iasifpex")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("by-pixel").short("p").long("by-pixel"))
	.arg(Arg::with_name("t-exp").long("t-exp").value_name("SECONDS").default_value("0.01"))
	.arg(Arg::with_name("input").multiple(true))
	.get_matches();

    let out_fn = args.value_of("out").expect("Specify path to output file");
    let nex_fns = args.values_of("input").expect("Specify input files (produced by extract_footprints)");
    let by_pixel = args.is_present("by-pixel");
    let t_exp : f64 = args.value_of("t-exp").unwrap().parse().expect("Invalid exposure time");

    let mut footprints = Vec::new();

    let re = regex::Regex::new(r"^IASI_xxx_1C_(M\d\d)_.*$")?;

    for nex_fn in nex_fns {
	info!("Processing file {}",nex_fn);

	// XXX: Have not been able to find an orbit number
	// No mention of the word orbit in the IASI level 1 product format specification
	// or in the provided Fortran interface
	let orbit = 0;

	let nex_path = PathBuf::from(nex_fn);
	let nex_stem = MiscError::from_option(nex_path.file_stem(),
					      "Cannot extract dataset name")?.to_string_lossy();
	let caps = MiscError::from_option(re.captures(&nex_stem),
					  "Cannot extract platform name")?;
	let platform = caps.get(1).unwrap().as_str();
	let instrument = "IASI";

	let mut nexs = IASINexIterator::new(nex_fn)?;
	let dataset_id = nexs.dataset_id.clone();

	let mut scan = Vec::new();
	let mut igra = 1;
	let mut done = false;
	let mut ncross = 0;

	while !done {
	    let mut flush = None;
	    match nexs.next() {
		Some(x) => {
		    if x.igra == igra {
			scan.push(x);
		    } else {
			igra = x.igra;
			flush = Some(Some(x));
		    }
		},
		None => {
		    flush = Some(None);
		    done = true;
		}
	    };
	    if let Some(fl) = flush {
		if scan.len() > 0 {
		    let igra = scan[0].igra;
		    let nscan = scan.len();

		    if by_pixel {
			for iscan in 0..nscan {
			    fn sca(k:f64,(x,y):(f64,f64))->(f64,f64) {
				(k*x,k*y)
			    }
			    fn add((x1,y1):(f64,f64),(x2,y2):(f64,f64))->(f64,f64) {
				(x1+x2,y1+y2)
			    }
			    fn sub((x1,y1):(f64,f64),(x2,y2):(f64,f64))->(f64,f64) {
				(x1-x2,y1-y2)
			    }
			    fn mix(p1:(f64,f64),a:f64,p2:(f64,f64))->(f64,f64) {
				add(p1,sca(1.0-a,sub(p2,p1)))
			    }
			    let sc = &scan[iscan];

			    let a = sc.outline[0]; // XXX check order
			    let b = sc.outline[1];
			    let c = sc.outline[2];
			    let d = sc.outline[3];

			    let centroid = sca(0.25,add(add(a,b),add(c,d)));

			    if amcut::crosses_antimeridian(&vec![d,c,b,a]) {
				ncross += 1;
				continue;
			    }
			    
			    let inter = |u:f64,v:f64|->(f64,f64) {
				let e = mix(a,u,d);
				let f = mix(b,u,c);
				mix(e,v,f)
			    };
			    let ntheta = 8;
			    for ipix in (0..4).rev() {
				let (x,y) = sc.outline[ipix];
				let id = format!("{}/{}/{}/{}",dataset_id,igra,iscan + 1,ipix + 1);
				let mut ring = Vec::new();
				for itheta in 0..ntheta {
				    let r = 0.5;
				    let theta = 2.0*itheta as f64*PI/(ntheta - 1) as f64;
				    let u = 0.5 + r*theta.cos();
				    let v = 0.5 + r*theta.sin();
				    let delta = sub(inter(u,v),centroid);
				    ring.push(add((x,y),delta));
				}

				let mut outline = Vec::new();
				if amcut::cut_and_push(&mut outline,ring) {
				    ncross += 1;
				}

				let mp = poly_utils::outline_to_multipolygon(&outline);
				let (x,y) = sc.outline[ipix];
				if !mp.contains(&Point::new(x,y)) {
				    warn!("Granule {} scan {} pixel {} coordinates x={} y={} not contained in\n{:#?}",
				    igra,iscan + 1,ipix + 1,x,y,mp);
				}

				let fp = Footprint{
				    orbit,
				    id:id.to_string(),
				    platform:platform.to_string(),
				    instrument:instrument.to_string(),
				    time_interval:(scan[iscan].t,scan[iscan].t + t_exp),
				    outline
				};
				footprints.push(fp);
			    }
			}
		    } else {
			let id = format!("{}/{}",dataset_id,igra);
			let mut ring = Vec::new();

			ring.push(scan[0].outline[3]);
			for i in 0..nscan {
			    ring.push(scan[i].outline[2]);
			}

			ring.push(scan[nscan - 1].outline[1]);

			for i in (1..nscan).rev() {
			    ring.push(scan[i].outline[0]);
			}
			
			let mut outline = Vec::new();
			if amcut::cut_and_push(&mut outline,ring) {
			    ncross += 1;
			}

			let t0 = scan.iter().fold(scan[0].t,|q,x| q.min(x.t));
			let t1 = scan.iter().fold(scan[0].t,|q,x| q.max(x.t));

			let fp = Footprint{
			    orbit,
			    id:id.to_string(),
			    platform:platform.to_string(),
			    instrument:instrument.to_string(),
			    time_interval:(t0,t1),
			    outline
			};

			footprints.push(fp);
		    }

		    scan.clear();
		}
		if let Some(x) = fl {
		    scan.push(x);
		}
	    }
	}
	info!("Number of scan lines that have been split due to crossing the meridian boundary: {}",ncross);
    }
    let fps = Footprints{ footprints };
    fps.save_to_file(out_fn)?;
    Ok(())
}
