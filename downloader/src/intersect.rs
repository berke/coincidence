#![allow(dead_code)]

mod misc_error;
mod minisvg;
mod footprint;

// use serde::Serialize;
use misc_error::MiscError;
use std::error::Error;
// use std::path::Path;
use minisvg::MiniSVG;
use footprint::{Footprint,Footprints};

use geo::{MultiPolygon,Polygon,LineString};
use geo::algorithm::{area::Area,intersects::Intersects};
use geo_clipper::Clipper;

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

fn polygon_to_vec(p:&Polygon<f64>)->Vec<Vec<(f64,f64)>> {
    let (pve1,pvi1) = p.clone().into_inner();
    let pve1 : Vec<(f64,f64)> = pve1.points_iter().map(|pt| (pt.x(),pt.y())).collect();
    let mut pvi1 : Vec<Vec<(f64,f64)>> =
	pvi1.iter().map(|ls| ls.points_iter().map(|pt| (pt.x(),pt.y())).collect()).collect();
    let mut u = Vec::new();
    u.push(pve1);
    u.append(&mut pvi1);
    u
}

fn multipolygon_to_vec(mp:&MultiPolygon<f64>)->Vec<Vec<Vec<(f64,f64)>>> {
    mp.iter().map(polygon_to_vec).collect()
}

const FACTOR : f64 = (1 << 24) as f64 / 360.0;

fn clip_to_roi(roi:&Polygon<f64>,mp:&MultiPolygon<f64>)->MultiPolygon<f64> {
    let mut res = Vec::new();
    for p in mp.iter() {
	if roi.intersects(p) {
	    let inter = roi.intersection(p,FACTOR);
	    let mut inter : Vec<Polygon<f64>> = inter.iter().map(|x| x.clone()).collect();
	    res.append(&mut inter);
	}
    }
    let mp_out : MultiPolygon<f64> = res.into();
    eprintln!("{}&{}={}",roi.unsigned_area(),mp.unsigned_area(),mp_out.unsigned_area());
    mp_out
}

fn check_intersection(m1:&MultiPolygon<f64>,m2:&MultiPolygon<f64>)->Option<(f64,MultiPolygon<f64>)> {
    if m1.intersects(m2) {
	let mv1 : Vec<&Polygon<f64>> = m1.iter().collect();
	let mv2 : Vec<&Polygon<f64>> = m2.iter().collect();
	let n1 = mv1.len();
	let n2 = mv2.len();
	//let factor = (1 << 48 / 360) as f64;
	let factor = (1 << 24) as f64 / 360.0;
	//eprintln!("Factor: {}",factor);
	let mut total_area = 0.0;
	// let mut msvg = MiniSVG::new("dbg.svg",360.0,180.0).unwrap();
	let mut mps = Vec::new();
	for i1 in 0..n1 {
	    let p1 = mv1[i1].clone();
	    eprintln!("|{}|={}",i1,p1.unsigned_area());
	    for i2 in 0..n2 {
		let p2 = mv2[i2];
		eprintln!("|{}|={}",i2,p2.unsigned_area());
		let inter : MultiPolygon<f64> = p1.intersection(p2,factor);
		for p in inter.iter() {
		    mps.push(p.clone());
		}
		eprintln!("|{} & {}| = {}",i1,i2,inter.unsigned_area());
		total_area += inter.unsigned_area();
		// msvg.set_stroke(Some((0x000000,0.25,1.0)));
		// msvg.set_fill(Some((0xff0000,0.50)));
		// msvg.polygon(&polygon_to_vec(mv1[i1])).unwrap();
		// msvg.set_fill(Some((0x00ff00,0.50)));
		// msvg.polygon(&polygon_to_vec(mv2[i2])).unwrap();
		// msvg.set_fill(Some((0x0000ff,0.50)));
		// for p in inter.iter() {
		//     msvg.polygon(&polygon_to_vec(p)).unwrap();
		// }
	    }
	}
	Some((total_area,MultiPolygon::from(mps)))
    } else {
	None
    }
}

fn main()->Result<(),Box<dyn Error>> {
    let fp1_fn = MiscError::from_option(std::env::args().nth(1),"Specify path to first footprint file")?;
    let fp2_fn = MiscError::from_option(std::env::args().nth(2),"Specify path to second footprint file")?;
    let delta_t_max = 3600.0;
    let fps1 = Footprints::from_file(fp1_fn)?;
    let fps2 = Footprints::from_file(fp2_fn)?;
    let n1 = fps1.footprints.len();
    let n2 = fps2.footprints.len();

    // Metropolitan France: Longitude -5 to 9, latitude 42 à 52
    let lon0 = -5.0;
    let lon1 = 9.0;
    let lat0 = 42.0;
    let lat1 = 52.0;
    let roi =
	Polygon::new(
	    LineString::from(vec![
		(lon0,lat0),
		(lon1,lat0),
		(lon1,lat1),
		(lon0,lat1)
	    ]),
	    vec![]);

    let mut msvg = MiniSVG::new("out.svg",360.0,180.0,-180.0,-90.0).unwrap();
    let mut n_inter = 0;
    for i1 in 0..n1 {
	let f1 = &fps1.footprints[i1];
	let f1_mp = clip_to_roi(&roi,&as_multipolygon(&f1));
	let t1 = f1.mean_time();
	for i2 in 0..n2 {
	    let f2 = &fps2.footprints[i2];
	    let t2 = f2.mean_time();
	    let delta_t = (t1 - t2).abs();
	    if delta_t < delta_t_max {
		let f2_mp = clip_to_roi(&roi,&as_multipolygon(&f2));
		if let Some((area,mp)) = check_intersection(&f1_mp,&f2_mp) {
		    eprintln!("Intersection {:04}: {} vs {} (time difference {}), pseudo-area: {}",
			     n_inter,f1.id,f2.id,delta_t,area);
		    println!("{:04} {} {} {} {}",n_inter,delta_t,area,f1.id,f2.id);
		    msvg.set_stroke(Some((0x000000,0.25,1.0)));
		    msvg.set_fill(Some((0xff0000,0.50)));
		    msvg.multi_polygon(&multipolygon_to_vec(&mp)).unwrap();
		    n_inter += 1;
		} else {
		    eprintln!("No intersection: {} vs {} (time difference {})",f1.id,f2.id,delta_t);
		}
	    }
	}
    }
    Ok(())
}
