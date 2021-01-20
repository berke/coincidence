#![allow(dead_code)]

mod misc_error;
mod minisvg;
mod footprint;

use serde::Serialize;
use misc_error::MiscError;
use std::error::Error;
use minisvg::MiniSVG;
use footprint::{Footprint,Footprints};

use geo::{MultiPolygon,Polygon,LineString};
use geo::algorithm::intersects::Intersects;

fn as_multipolygon(f:&Footprint)->MultiPolygon<f64> {
    let mut u = Vec::new();
    // f.outline: Vec<Vec<Vec<(f64,f64)>>>
    // f.outline.iter(): &Vec<Vec<(f64,f64)>>
    // f.outline.iter().iter(): &Vec<(f64,f64)>
    for a in f.outline.iter() {
	let m = a.len();
	if m > 0 {
	    let exterior : LineString<f64> = a[0].clone().into();
	    let interior : Vec<LineString<f64>> = a.iter().skip(1).map(|o| {
		let ls : LineString<f64> = o.clone().into();
		ls
	    }).collect();
	    let poly = Polygon::new(exterior,interior);
	    u.push(poly);
	}
    }
    MultiPolygon::from(u)
}

fn check_intersection(f1:&Footprint,f2:&Footprint)->bool {
    let m1 = as_multipolygon(f1);
    let m2 = as_multipolygon(f2);
    m1.intersects(&m2)
}

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
		let x = check_intersection(f1,f2);
		if x {
		    println!("Intersection: {} vs {} (time difference {})",f1.id,f2.id,delta_t);
		} else {
		    println!("No intersection: {} vs {} (time difference {})",f1.id,f2.id,delta_t);
		}
	    }
	}
    }
    Ok(())
}
