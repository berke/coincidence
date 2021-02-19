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
use chrono::{Utc,TimeZone,NaiveDateTime,DateTime};
use geo::{MultiPolygon,Polygon,LineString};
use geo::algorithm::{area::Area,intersects::Intersects};
use geo_clipper::Clipper;

use footprint::Footprints;
use poly_utils::{clip_to_roi,outline_to_multipolygon,FACTOR};

fn check_intersection(m1:&MultiPolygon<f64>,m2:&MultiPolygon<f64>)->Option<(f64,MultiPolygon<f64>)> {
    if m1.intersects(m2) {
	let mv1 : Vec<&Polygon<f64>> = m1.iter().collect();
	let mv2 : Vec<&Polygon<f64>> = m2.iter().collect();
	let n1 = mv1.len();
	let n2 = mv2.len();
	let mut total_area = 0.0;
	let mut mps = Vec::new();
	for i1 in 0..n1 {
	    let p1 = mv1[i1].clone();
	    for i2 in 0..n2 {
		let p2 = mv2[i2];
		let inter : MultiPolygon<f64> = p1.intersection(p2,FACTOR);
		for p in inter.iter() {
		    mps.push(p.clone());
		}
		total_area += inter.unsigned_area();
	    }
	}
	Some((total_area,MultiPolygon::from(mps)))
    } else {
	None
    }
}

fn main()->Result<(),Box<dyn Error>> {
    let args = App::new("intersect")
	.arg(Arg::with_name("input1").short("i1").long("input1").required(true).takes_value(true))
	.arg(Arg::with_name("input2").short("i2").long("input2").required(true).takes_value(true))
	.arg(Arg::with_name("report").short("r").long("report").required(true)
	     .help("Path to output report to be created")
	     .takes_value(true))
	.arg(Arg::with_name("output_base").short("o").long("output-base")
	     .help("Base name for footprint output files")
	     .takes_value(true))
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
	.arg(Arg::with_name("tau_min").long("tau").default_value("0.0")
	     .help("Minimum temporal overlap ratio"))
	.arg(Arg::with_name("min_overlap").long("min-overlap").default_value("0.50")
	     .help("Minimal overal pseudo-area fraction with respect to ROI"))
	.arg(Arg::with_name("t_min").long("t-min").help("Start of time range").takes_value(true))
	.arg(Arg::with_name("t_max").long("t-max").help("End of time range").takes_value(true))
	.arg(Arg::with_name("verbose").short("v"))
	.get_matches();

    let verbose = args.is_present("verbose");

    simple_logger::SimpleLogger::new()
	.with_level(if verbose { log::LevelFilter::Trace } else { log::LevelFilter::Info })
	.init()?;

    let fp1_fn = args.value_of("input1").unwrap();
    let fp2_fn = args.value_of("input2").unwrap();
    let report_fn = args.value_of("report").unwrap();

    let min_overlap : f64 = args.value_of("min_overlap").unwrap().parse().expect("Invalid spatial overlap threshold");
    let delta_t_max : f64 = args.value_of("delta_t").unwrap().parse().expect("Invalid time limit");
    let tau_min : f64 = args.value_of("tau_min").unwrap().parse().expect("Invalid temporal overlap threshold");
    let lon0 : f64 = args.value_of("lon0").unwrap().parse().expect("Invalid starting longitude");
    let lat0 : f64 = args.value_of("lat0").unwrap().parse().expect("Invalid starting latitude");
    let lon1 : f64 = args.value_of("lon1").unwrap().parse().expect("Invalid ending longitude");
    let lat1 : f64 = args.value_of("lat1").unwrap().parse().expect("Invalid ending latitude");
    let t_min =
	if let Some(ts) = args.value_of("t_min") {
	    DateTime::<Utc>::from_utc(NaiveDateTime::parse_from_str(ts,"%Y-%m-%dT%H:%M:%S")?,Utc)
		.timestamp_millis() as f64 / 1000.0
	} else {
	    0.0
	};
    let t_max =
	if let Some(ts) = args.value_of("t_max") {
	    DateTime::<Utc>::from_utc(NaiveDateTime::parse_from_str(ts,"%Y-%m-%dT%H:%M:%S")?,Utc)
		.timestamp_millis() as f64 / 1000.0
	} else {
	    std::f64::INFINITY
	};

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

    info!("Loading first set of footprints from {}",fp1_fn);
    let fps1 = Footprints::from_file(fp1_fn)?;
    let n1 = fps1.footprints.len();

    info!("Loading second set of footprints from {}",fp2_fn);
    let fps2 = Footprints::from_file(fp2_fn)?;
    let n2 = fps2.footprints.len();

    let mut n_inter = 0;

    info!("Number of footprints in first file: {}",n1);
    info!("Number of footprints in second file: {}",n2);

    let mut n_time_match = 0;
    let mut n_insufficient_time_overlap = 0;
    let mut n_insufficient_overlap = 0;

    let report_fd = File::create(report_fn)?;
    let mut report_buf = BufWriter::new(report_fd);

    let mut fps_in_roi1 = Vec::new();
    let mut fps_in_roi2 = Vec::new();

    for i1 in 0..n1 {
	let f1 = &fps1.footprints[i1];
	if !(t_min <= f1.time_interval.0 && f1.time_interval.1 < t_max) {
	    continue;
	}
	if let Some(f1_mp) = clip_to_roi(&roi,&outline_to_multipolygon(&f1.outline)) {
	    fps_in_roi1.push((i1,f1_mp));
	} else {
	    trace!("Rejected {} as it does not meet the ROI",f1.id);
	}
    }

    for i2 in 0..n2 {
	let f2 = &fps2.footprints[i2];
	if !(t_min <= f2.time_interval.0 && f2.time_interval.1 < t_max) {
	    continue;
	}

	if let Some(f2_mp) = clip_to_roi(&roi,&outline_to_multipolygon(&f2.outline)) {
	    fps_in_roi2.push((i2,f2_mp));
	} else {
	    trace!("Rejected {} as it does not meet the ROI",f2.id);
	}
    }

    info!("Number of footprints in first file meeting the ROI: {} ({:5.2}%)",
	  fps_in_roi1.len(),
	  100.0*fps_in_roi1.len() as f64/n1 as f64);
    info!("Number of footprints in second file meeting the ROI: {} ({:5.2}%)",
	  fps_in_roi2.len(),
	  100.0*fps_in_roi2.len() as f64/n2 as f64);

    for &(i1,ref f1_mp) in fps_in_roi1.iter() {
	let f1 = &fps1.footprints[i1];
	for &(i2,ref f2_mp) in fps_in_roi2.iter() {
	    let f2 = &fps2.footprints[i2];

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
		// Temporal overlap radio
		let tau =
		    if min_delta_t > 0.0 {
			0.0
		    } else {
			(f1.time_interval.1.min(f2.time_interval.1) - f1.time_interval.0.max(f2.time_interval.0)) /
			    (f1.time_interval.1.max(f2.time_interval.1) - f1.time_interval.0.min(f2.time_interval.0))
		    };
		n_time_match += 1;
		if tau >= tau_min {
		    if let Some((area,_mp)) = check_intersection(f1_mp,f2_mp) {
			let area_ratio = area / roi_area;
			if area_ratio > min_overlap {
			    let t0 = f1.time_interval.0.min(f2.time_interval.0);
			    let t1 = f1.time_interval.1.max(f2.time_interval.1);
			    let ts0 = Utc.timestamp(t0.floor() as i64,(t0.fract() * 1e9 + 0.5).floor() as u32);
			    let ts1 = Utc.timestamp(t1.floor() as i64,(t1.fract() * 1e9 + 0.5).floor() as u32);
			    trace!("F1 {:?} F2 {:?}",f1.time_interval,f2.time_interval);

			    trace!("Intersection {:04}: {} vs {} (time difference {}, tau {}), pseudo-area ratio: {}, time: {} to {}",
				   n_inter,f1.id,f2.id,min_delta_t,tau,area_ratio,ts0,ts1);
			    writeln!(report_buf,"{:04}\t{}\t{}\t{:5.1}\t{:5.3}\t{:5.3}\t{}\t{}",
				     n_inter,
				     ts0,
				     ts1,
				     min_delta_t,tau,area_ratio,f1.id,f2.id)?;

			    if let Some(fp_fn) = args.value_of("output_base") {
				let mut f1c = f1.clone();
				let mut f2c = f2.clone();
				let mut f1ci = f1.clone();
				let mut f2ci = f2.clone();
				f1c.id = format!("FP1/{}/{}",n_inter,f1.id);
				f2c.id = format!("FP2/{}/{}",n_inter,f2.id);
				f1ci.id = format!("ROI1/{}/{}",n_inter,f1.id);
				f2ci.id = format!("ROI2/{}/{}",n_inter,f2.id);
				f1ci.outline = poly_utils::multipolygon_to_vec(f1_mp);
				f2ci.outline = poly_utils::multipolygon_to_vec(f2_mp);
				let fps = Footprints{ footprints:vec![f1c,f2c,f1ci,f2ci] };
				fps.save_to_file(&format!("{}-{:05}.mpk",fp_fn,n_inter))?;
			    }
			    
			    n_inter += 1;
			} else {
			    n_insufficient_overlap += 1;
			}
		    } else {
			trace!("No intersection: {} vs {} (time difference {})",f1.id,f2.id,min_delta_t);

			if let Some(fp_fn) = args.value_of("output_base") {
			    let mut f1c = f1.clone();
			    let mut f2c = f2.clone();
			    f1c.id = format!("FP1/{}",f1.id);
			    f2c.id = format!("FP2/{}",f2.id);
			    f1c.outline = poly_utils::multipolygon_to_vec(f1_mp);
			    f2c.outline = poly_utils::multipolygon_to_vec(f2_mp);
			    let fps = Footprints{ footprints:vec![f1c,f2c] };
			    fps.save_to_file(&format!("{}-no_inter-{:05}-{:05}.mpk",fp_fn,i1,i2))?;
			}
		    }
		} else {
		    n_insufficient_time_overlap += 1;
		    trace!("Rejected {} vs {} due to tau = {}",f1.id,f2.id,tau);
		}
	    } else {
		trace!("Rejected {} vs {} due to delta_t = {}",f1.id,f2.id,min_delta_t);
	    }
	}
    }
    info!("Number of pairs tested: {}",n_time_match);
    info!("Number of pairs rejected due to insufficient overlapping pseudo-area: {}",n_insufficient_overlap);
    info!("Number of pairs rejected due to insufficient time overlap: {}",n_insufficient_time_overlap);
    info!("Number of intersections found: {}",n_inter);
    
    Ok(())
}
