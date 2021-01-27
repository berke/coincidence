#![allow(dead_code)]

mod misc_error;
mod minisvg;
mod footprint;

// use serde::Serialize;
use misc_error::MiscError;
use std::error::Error;
// use std::path::Path;
use log::{info,trace};
use clap::{Arg,App};
use minisvg::MiniSVG;
use footprint::{Footprint,Footprints};

// use geo::{MultiPolygon,Polygon,LineString};
// use geo::algorithm::{area::Area,intersects::Intersects};
// use geo_clipper::Clipper;

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;

    let args = App::new("fptool")
	.arg(Arg::with_name("input").multiple(true))
	.get_matches();

    let fp_fns = args.values_of("input").expect("Specify footprint files");
    for fp_fn in fp_fns {
	info!("Footprint file {}",fp_fn);
	let fps = Footprints::from_file(fp_fn)?;
	let m = fps.footprints.len();
	info!("Number of footprints: {}",m);
	for i in 0..m{
	    let fp = &fps.footprints[i];
	    info!("Time: {} to {}",fp.time_interval.0,fp.time_interval.1);
	    info!("Platform: {}",fp.platform);
	    info!("Instrument: {}",fp.instrument);
	    info!("ID: {}",fp.id);
	}
    }
    Ok(())
}
