#![allow(dead_code)]

mod misc_error;
mod minisvg;
mod footprint;

use serde::Serialize;
use misc_error::MiscError;
use std::error::Error;
use minisvg::MiniSVG;
use footprint::{Footprint,Footprints};

fn main()->Result<(),Box<dyn Error>> {
    let fp1_fn = MiscError::from_option(std::env::args().nth(1),"Specify path to first footprint file")?;
    let fp2_fn = MiscError::from_option(std::env::args().nth(2),"Specify path to second footprint file")?;
    let delta_t_max = 3600.0;
    let fps1 = Footprints::from_file(fp1_fn)?;
    let fps2 = Footprints::from_file(fp2_fn)?;
    let n1 = fps1.footprints.len();
    let n2 = fps2.footprints.len();
    for i1 in 0..n1 {
	let f1 = &fps1.footprints[i1];
	let t1 = f1.mean_time();
	for i2 in 0..n2 {
	    let f2 = &fps2.footprints[i2];
	    let t2 = f2.mean_time();
	    let delta_t = (t1 - t2).abs();
	    if delta_t < delta_t_max {
		println!("Checking {} vs {} (time difference {})",f1.id,f2.id,delta_t);
	    }
	}
    }
    Ok(())
}
