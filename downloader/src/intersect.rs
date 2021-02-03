#![allow(dead_code)]

mod misc_error;
mod minisvg;
mod footprint;
mod poly_utils;

use std::error::Error;
use std::fs::File;
use std::io::{Write,BufWriter};
use log::{trace,info};
use clap::{Arg,App};
use chrono::{Utc,TimeZone};
use geo::{MultiPolygon,Polygon,LineString};
use geo::algorithm::{area::Area,intersects::Intersects};
use geo_clipper::Clipper;

use minisvg::MiniSVG;
use footprint::Footprints;
use poly_utils::{multipolygon_to_vec,clip_to_roi,outline_to_multipolygon,FACTOR};

// fn as_multipolygon(f:&Footprint)->MultiPolygon<f64> {
//     let mut u = Vec::new();
//     // f.outline: Vec<Vec<Vec<(f64,f64)>>>
//     // f.outline.iter(): &Vec<Vec<(f64,f64)>>
//     // f.outline.iter().iter(): &Vec<(f64,f64)>
//     for a in f.outline.iter() {
// 	let m = a.len();
// 	if m > 0 {
// 	    let exterior : LineString<f64> = a[0].clone().into();
// 	    let interior : Vec<LineString<f64>> = a.iter().skip(1).map(|o| {
// 		let ls : LineString<f64> = o.clone().into();
// 		ls
// 	    }).collect();
// 	    let poly = Polygon::new(exterior,interior);
// 	    u.push(poly);
// 	}
//     }
//     MultiPolygon::from(u)
// }

// fn polygon_to_vec(p:&Polygon<f64>)->Vec<Vec<(f64,f64)>> {
//     let (pve1,pvi1) = p.clone().into_inner();
//     let pve1 : Vec<(f64,f64)> = pve1.points_iter().map(|pt| (pt.x(),pt.y())).collect();
//     let mut pvi1 : Vec<Vec<(f64,f64)>> =
// 	pvi1.iter().map(|ls| ls.points_iter().map(|pt| (pt.x(),pt.y())).collect()).collect();
//     let mut u = Vec::new();
//     u.push(pve1);
//     u.append(&mut pvi1);
//     u
// }

// fn multipolygon_to_vec(mp:&MultiPolygon<f64>)->Vec<Vec<Vec<(f64,f64)>>> {
//     mp.iter().map(polygon_to_vec).collect()
// }

// const FACTOR : f64 = (1 << 24) as f64 / 360.0;

// fn clip_to_roi(roi:&Polygon<f64>,mp:&MultiPolygon<f64>)->MultiPolygon<f64> {
//     let mut res = Vec::new();
//     for p in mp.iter() {
// 	if roi.intersects(p) {
// 	    let inter = roi.intersection(p,FACTOR);
// 	    let mut inter : Vec<Polygon<f64>> = inter.iter().map(|x| x.clone()).collect();
// 	    res.append(&mut inter);
// 	}
//     }
//     let mp_out : MultiPolygon<f64> = res.into();
//     trace!("{}&{}={}",roi.unsigned_area(),mp.unsigned_area(),mp_out.unsigned_area());
//     mp_out
// }

fn check_intersection(m1:&MultiPolygon<f64>,m2:&MultiPolygon<f64>)->Option<(f64,MultiPolygon<f64>)> {
    if m1.intersects(m2) {
	let mv1 : Vec<&Polygon<f64>> = m1.iter().collect();
	let mv2 : Vec<&Polygon<f64>> = m2.iter().collect();
	let n1 = mv1.len();
	let n2 = mv2.len();
	//let factor = (1 << 48 / 360) as f64;
	// let factor = (1 << 24) as f64 / 360.0;
	//eprintln!("Factor: {}",factor);
	let mut total_area = 0.0;
	// let mut msvg = MiniSVG::new("dbg.svg",360.0,180.0).unwrap();
	let mut mps = Vec::new();
	for i1 in 0..n1 {
	    let p1 = mv1[i1].clone();
	    trace!("|{}|={}",i1,p1.unsigned_area());
	    for i2 in 0..n2 {
		let p2 = mv2[i2];
		trace!("|{}|={}",i2,p2.unsigned_area());
		let inter : MultiPolygon<f64> = p1.intersection(p2,FACTOR);
		for p in inter.iter() {
		    mps.push(p.clone());
		}
		trace!("|{} & {}| = {}",i1,i2,inter.unsigned_area());
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
    simple_logger::SimpleLogger::new()
	.with_level(log::LevelFilter::Info)
	.init()?;

    let args = App::new("intersect")
	.arg(Arg::with_name("input1").short("i1").long("input1").required(true).takes_value(true))
	.arg(Arg::with_name("input2").short("i2").long("input2").required(true).takes_value(true))
	.arg(Arg::with_name("lon0").long("lon0").default_value("-5.0")
	     .help("Starting longitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lon1").long("lon1").default_value("9.0")
	     .help("Ending longitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lat0").long("lat0").default_value("42.0")
	     .help("Starting latitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lat1").long("lat1").default_value("52.0")
	     .help("Ending latitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("delta_t").long("delta-t").default_value("13200.0")
	     .help("Maximum mean time difference (s)"))
	.arg(Arg::with_name("min_overlap").long("min-overlap").default_value("0.50")
	     .help("Minimal overal pseudo-area fraction with respect to ROI"))
	.get_matches();

    let fp1_fn = args.value_of("input1").unwrap();
    let fp2_fn = args.value_of("input2").unwrap();

    info!("Loading first set of footprints from {}",fp1_fn);
    let fps1 = Footprints::from_file(fp1_fn)?;
    let n1 = fps1.footprints.len();

    info!("Loading second set of footprints from {}",fp2_fn);
    let fps2 = Footprints::from_file(fp2_fn)?;
    let n2 = fps2.footprints.len();

    let min_overlap : f64 = args.value_of("min_overlap").unwrap().parse().expect("Invalid overlap threshold");
    let delta_t_max : f64 = args.value_of("delta_t").unwrap().parse().expect("Invalid time limit");
    let lon0 : f64 = args.value_of("lon0").unwrap().parse().expect("Invalid starting longitude");
    let lat0 : f64 = args.value_of("lat0").unwrap().parse().expect("Invalid starting latitude");
    let lon1 : f64 = args.value_of("lon1").unwrap().parse().expect("Invalid ending longitude");
    let lat1 : f64 = args.value_of("lat1").unwrap().parse().expect("Invalid ending latitude");
    info!("ROI: latitudes {} to {}, longitudes {} to {}",lat0,lat1,lon0,lon1);

    let roi =
	Polygon::new(
	    LineString::from(vec![
		(lon0,lat0),
		(lon1,lat0),
		(lon1,lat1),
		(lon0,lat1)
	    ]),
	    vec![]);
    let roi_area = roi.unsigned_area();

    let mut msvg = MiniSVG::new("out.svg",lon1-lon0,lat1-lat0,lon0,lat0).unwrap();
    let mut n_inter = 0;

    info!("Number of footprints in first file: {}",n1);
    info!("Number of footprints in second file: {}",n2);

    let mut n_time_match = 0;
    let mut n_insufficient_overlap = 0;

    let report_path = "out.dat";
    let report_fd = File::create(report_path)?;
    let mut report_buf = BufWriter::new(report_fd);

    for i1 in 0..n1 {
	let f1 = &fps1.footprints[i1];
	let f1_mp = clip_to_roi(&roi,&outline_to_multipolygon(&f1.outline));
	// let t1 = f1.mean_time();
	for i2 in 0..n2 {
	    let f2 = &fps2.footprints[i2];
	    // let t2 = f2.mean_time();

	    let min_delta_t =
		if f1.time_interval.1 <= f2.time_interval.0 {
		    f2.time_interval.0 - f1.time_interval.1
		} else {
		    if f2.time_interval.1 <= f1.time_interval.0 {
			f1.time_interval.0 - f2.time_interval.1
		    } else {
			0.0
		    }
		};
	    
	    if min_delta_t <= delta_t_max {
		n_time_match += 1;
		let f2_mp = clip_to_roi(&roi,&outline_to_multipolygon(&f2.outline));
		if let Some((area,mp)) = check_intersection(&f1_mp,&f2_mp) {
		    let area_ratio = area / roi_area;
		    if area_ratio > min_overlap {
			let t0 = f1.time_interval.0.min(f2.time_interval.0);
			let t1 = f1.time_interval.1.max(f2.time_interval.1);
			let ts0 = Utc.timestamp(t0.floor() as i64,(t0.fract() * 1e9 + 0.5).floor() as u32);
			let ts1 = Utc.timestamp(t1.floor() as i64,(t1.fract() * 1e9 + 0.5).floor() as u32);
			info!("F1 {:?} F2 {:?}",f1.time_interval,f2.time_interval);

			info!("Intersection {:04}: {} vs {} (time difference {}), pseudo-area ratio: {}, time: {} to {}",
			      n_inter,f1.id,f2.id,min_delta_t,area_ratio,ts0,ts1);
			writeln!(report_buf,"|| {:04} || {} || {} || {:5.1} || {:5.3} || `{}` || `{}` ||",
				 n_inter,
				 ts0,
				 ts1,
				 min_delta_t,area_ratio,f1.id,f2.id)?;
			msvg.set_stroke(Some((0x000000,0.25,1.0)));
			msvg.set_fill(Some((0xff0000,0.50)));
			msvg.multi_polygon(&multipolygon_to_vec(&mp)).unwrap();
		    } else {
			n_insufficient_overlap += 1;
		    }
		    n_inter += 1;
		} else {
		    trace!("No intersection: {} vs {} (time difference {})",f1.id,f2.id,min_delta_t);
		}
	    }
	}
    }
    info!("Number of pairs tested: {}",n_time_match);
    info!("Number of pairs rejected due to insufficient overlapping pseudo-area: {}",n_insufficient_overlap);
    info!("Number of intersections found: {}",n_inter);
    Ok(())
}
