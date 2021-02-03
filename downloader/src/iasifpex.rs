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

use log::{error,info};
use chrono::{DateTime,NaiveDate,Utc};
use clap::{Arg,App};
use misc_error::MiscError;
use footprint::{Footprint,Footprints};

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
		let us : Vec<u32> = xs[0..10].iter().map(|x| x.parse::<u32>().expect("Invalid integer")).collect();
		let fs : Vec<f64> = xs[10..].iter().map(|x| x.parse::<f64>().expect("Invalid integer")).collect();
		let t_pixel = DateTime::<Utc>::from_utc(
		    NaiveDate::from_ymd(us[2] as i32,us[3],us[4]).and_hms(us[5],us[6],us[7]),Utc);
		let t = t_pixel.timestamp_millis() as f64 / 1000.0;
		let igra = us[0];
		let iscan = us[1];
		let outline = [(fs[0],fs[4]), (fs[1],fs[5]), (fs[2],fs[6]), (fs[3],fs[7])];
		Some(IASINexRow{
		    t,
		    igra,
		    iscan,
		    outline})
	    },
	    Err(e) => {
		error!("Error reading file {:?}: {}",self.path,e);
		None
	    }
	}
    }
}

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;

    let args = App::new("iasifpex")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("input").multiple(true))
	.get_matches();

    let out_fn = args.value_of("out").expect("Specify path to output file");
    let nex_fns = args.values_of("input").expect("Specify input files (produced by extract_footprints)");

    let mut footprints = Vec::new();

    for nex_fn in nex_fns {
	info!("Processing file {}",nex_fn);

	let orbit = 0; // XXX
	let platform = "METOP-*"; // XXX
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
		    let npix = scan.len();
		    info!("Granule {}: got {} pixels",igra,npix);

		    let id = format!("{}/{}",dataset_id,igra);
		    let mut ring = Vec::new();

		    ring.push(scan[0].outline[3]);
		    for i in 0..npix {
			ring.push(scan[i].outline[2]);
		    }

		    ring.push(scan[npix - 1].outline[1]);

		    for i in (1..npix).rev() {
			ring.push(scan[i].outline[0]);
		    }
		    
		    let mut outline = Vec::new();
		    if amcut::cut_and_push(&mut outline,ring) {
			ncross += 1;
		    }
		    // let outline = vec![vec![poly]];

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
