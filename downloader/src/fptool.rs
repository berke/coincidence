#![allow(dead_code)]

mod misc_error;
mod minisvg;
mod footprint;

use std::error::Error;
use log::info;
use clap::{Arg,App};
use chrono::{Utc,TimeZone};
use footprint::Footprints;

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
	    let (t0,t1) = fp.time_interval;
	    let ts0 = Utc.timestamp(t0.floor() as i64,(t0.fract() * 1e9 + 0.5).floor() as u32);
	    let ts1 = Utc.timestamp(t1.floor() as i64,(t1.fract() * 1e9 + 0.5).floor() as u32);
	    info!("Time: {} to {}",ts0,ts1);
	    info!("Orbit: {}",fp.orbit);
	    info!("Platform: {}",fp.platform);
	    info!("Instrument: {}",fp.instrument);
	    info!("ID: {}",fp.id);
	}
    }
    Ok(())
}
