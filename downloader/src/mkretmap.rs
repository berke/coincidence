#![allow(dead_code)]
mod misc_error;
mod footprint;
mod minisvg;
mod amcut;
mod poly_utils;

use std::error::Error;
use std::ffi::OsString;
use std::path::PathBuf;

use log::{error,info};
use clap::{Arg,App};
use misc_error::MiscError;
use footprint::{Footprint,FootprintLike,Footprints};
use ndarray::{s,Array1,Array2};
use std::collections::{BTreeMap,BTreeSet};
use serde_json::{Map,to_value};

struct FancyFootprint {
    fp:Footprint,
    xch4:f64,
    sigma_xch4:f64
}

impl FootprintLike for FancyFootprint {
    fn orbit(&self)->usize { self.fp.orbit() }
    fn id(&self)->&str { self.fp.id() }
    fn platform(&self)->&str { self.fp.platform() }
    fn instrument(&self)->&str { self.fp.instrument() }
    fn time_interval(&self)->(f64,f64) { self.fp.time_interval() }
    fn outline(&self)->&Vec<Vec<Vec<(f64,f64)>>> { self.fp.outline() }
    fn properties(&self)->Map<String,serde_json::Value> {
	let mut map = Map::new();
	map.insert(String::from("xch4"),to_value(self.xch4).unwrap());
	map.insert(String::from("sigma_xch4"),to_value(self.sigma_xch4).unwrap());
	map
    }
}

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;
    let _ = hdf5::silence_errors();

    let args = App::new("mkretmap")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("input").short("i").long("input").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("iasifpdir").long("iasifpdir").value_name("PATH").takes_value(true).required(true))
	.get_matches();

    let out_fn = args.value_of("out").expect("Specify path to output file");
    let input_dir = args.value_of("input").expect("Specify input directory");
    let iasi_fp_dir = args.value_of("iasifpdir").expect("Specify IASI footprint directory");
    
    let iasi_ret_re = regex::Regex::new(r"^(IASI_xxx_.*)-(\d+)-(\d+)-(\d+)-ret.h5$")?;

    struct Retrieval {
	path:OsString,
	base:String,
	igra:usize,
	iscan:usize,
	ipix:usize
    }

    // Get retrievals
    let mut retrievals = Vec::new();

    let mut ids : BTreeSet<String> = BTreeSet::new();

    'outer: for dent in std::fs::read_dir(input_dir)?.flatten() {
	if dent.file_type()?.is_file() {
	    let path = dent.path();
	    if let Some(name) = path.file_name() {
		if let Some(u) = name.to_str() {
		    if let Some(cap) = iasi_ret_re.captures(u) {
			let base = MiscError::from_option(cap.get(1),"Bad base name")?.as_str();
			let igra =
			    MiscError::from_option(cap.get(2),"Bad granule")?
			    .as_str()
			    .parse::<usize>()?;
			let iscan =
			    MiscError::from_option(cap.get(3),"Bad scan")?
			    .as_str()
			    .parse::<usize>()?;
			let ipix =
			    MiscError::from_option(cap.get(4),"Bad pixel")?
			    .as_str()
			    .parse::<usize>()?;
			let id = format!("{}/{}/{}/{}",base,igra,iscan,ipix);
			ids.insert(id);
			retrievals.push(Retrieval{
			    path:path.clone().into_os_string(),
			    base:base.to_string(),
			    igra,
			    iscan,
			    ipix
			});
			break 'outer;
		    }
		}
	    }
	}
    }

    // Figure out which MPKs to load
    let mpk_names : BTreeSet<String> =
	retrievals.iter().map(|r| r.base.clone()).collect();

    let mut index : BTreeMap<String,Footprint> = BTreeMap::new();

    // Load the footprints
    for name in mpk_names.iter() {
    // let fp_from_path = |name:&String|->Result<(String,Footprints),Box<dyn Error>> {
	let mut path : PathBuf = iasi_fp_dir.into();
	path.push(name);
	path.set_extension("mpk");
	let fps = Footprints::from_file(&path)?;

	let m = fps.footprints.len();

	// Filter footprints
	let mut m_kept = 0;
	for fp in fps.footprints.iter() {
	    let id = fp.id();
	    if ids.contains(id) {
		index.insert(id.to_string(),fp.clone());
		m_kept += 1;
	    }
	}
	info!("Loaded {} footprints from {:?}, kept {}",m,path,m_kept);
    }
	
    // Process retrievals
    let mut footprints = Vec::new();
    for Retrieval { path, base, igra, iscan, ipix } in retrievals.iter() {
	info!("Opening {:?}",path);
	let fd = hdf5::File::open(path)?;

	let xstar : Array1<f64> = fd.dataset("/res/xstar")?.read_1d()?;
	let sxp : Array2<f64> = fd.dataset("/oi/sxp")?.read_2d()?;
	let im_ch4 = fd.group("/im/ch4")?;
	let ch4_i0 : usize = im_ch4.dataset("i0")?.read_scalar()?;
	let ch4_i1 : usize = im_ch4.dataset("i1")?.read_scalar()?;
	let operator_tc : Array1<f64> = im_ch4.dataset("units/ppmv_tc/operator")?.read_1d()?;
	let sxp_ch4 = sxp.slice(s![ch4_i0..ch4_i1,ch4_i0..ch4_i1]);
	let sigma_xch4 = operator_tc.dot(&sxp_ch4.dot(&operator_tc));
	let xch4 = operator_tc.dot(&xstar.slice(s![ch4_i0..ch4_i1]));
	// info!("XCH4 = {}",xch4);

	let id = format!("{}/{}/{}/{}",base,igra,iscan,ipix);
	if let Some(fp) = index.get(&id) {
	    let ffp = FancyFootprint {
		fp:(*fp).clone(),
		xch4,
		sigma_xch4
	    };
	    footprints.push(ffp);
	} else {
	    error!("Couldn't find footprint {}",id);
	}
    }

    info!("Exporting GeoJSON to {:?}",out_fn);
    footprint::export_geojson(&footprints,&out_fn)?;

    Ok(())
}
