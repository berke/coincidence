#![allow(dead_code)]

mod misc_error;
mod poly_utils;
mod progress;
mod report;
mod stats;

use std::error::Error;
use std::fs::File;
use std::io::{Write,BufWriter};
use std::path::Path;
use log::{trace,info,error};
use clap::{Arg,App};
use chrono::{Utc,TimeZone,NaiveDateTime,DateTime};
use geo::{Distance,MultiPolygon,Polygon,LineString};
use geo::algorithm::{area::Area,
		     centroid::Centroid,
		     intersects::Intersects,
		     line_measures::metric_spaces::Rhumb};
use geo_clipper::Clipper;

use footprint::Footprints;
use poly_utils::{clip_to_roi,outline_to_multipolygon,FACTOR};
use report::{Report,ReportLine};
use stats::StatEstimator;
use progress::ProgressIndicator;

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
	.arg(Arg::with_name("delta_t_max").long("delta-t-max").default_value("13200.0")
	     .help("Maximum mean time difference (s)"))
	.arg(Arg::with_name("tau_min").long("tau-min").default_value("0.0")
	     .help("Minimum temporal overlap ratio"))
	.arg(Arg::with_name("t_min").long("t-min").help("Start of time range").takes_value(true))
	.arg(Arg::with_name("t_max").long("t-max").help("End of time range").takes_value(true))
	.arg(Arg::with_name("dist_max").long("dist-max").help("Maximum distance").takes_value(true))
	.arg(Arg::with_name("verbose").short("v"))
	.arg(Arg::with_name("save_no_inter").long("save-no-inter").help("Save diagnostic MPK files for pairs that do not have an intersection"))
	.arg(Arg::with_name("psi_min").long("psi-min").default_value("0.50")
	     .help("Minimal overlap ratio between footprints"))
	.arg(Arg::with_name("omega_min").long("omega-min").default_value("0.0")
	     .help("Minimum overlap ratio with ROI"))
	.get_matches();

    let verbose = args.is_present("verbose");
    let save_no_inter = args.is_present("save_no_inter");

    simple_logger::SimpleLogger::new()
	.with_level(if verbose { log::LevelFilter::Trace } else { log::LevelFilter::Info })
	.init()?;

    let fp1_fn = args.value_of("input1").unwrap();
    let fp2_fn = args.value_of("input2").unwrap();
    let report_fn = args.value_of("report").unwrap();

    let dist_max : f64 = args.value_of("dist_max").unwrap().parse().expect("Invalid distance limit");
    let delta_t_max : f64 = args.value_of("delta_t_max").unwrap().parse().expect("Invalid time limit");
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
    let omega_min : f64 = args.value_of("omega_min")
	.unwrap().parse().expect("Invalid omega value");
    let psi_min : f64 = args.value_of("psi_min")
	.unwrap().parse().expect("Invalid psi value");

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
    // let roi_area = roi.unsigned_area();

    info!("Loading first set of footprints from {}",fp1_fn);
    let fps1 = Footprints::from_file(fp1_fn)?;
    let n1 = fps1.footprints.len();

    info!("Loading second set of footprints from {}",fp2_fn);
    let fps2 = Footprints::from_file(fp2_fn)?;
    let n2 = fps2.footprints.len();

    let mut n_inter = 0;

    info!("Number of footprints in first file: {}",n1);
    info!("Number of footprints in second file: {}",n2);

    let mut n_not_in_time_interval1 = 0;
    let mut n_not_in_time_interval2 = 0;
    let mut n_omega_too_low1 = 0;
    let mut n_omega_too_low2 = 0;

    let mut report = Report::new(report_fn)?;
    report.show_header()?;

    let mut fps_in_roi1 = Vec::new();
    let mut fps_in_roi2 = Vec::new();

    for i1 in 0..n1 {
	let f1 = &fps1.footprints[i1];
	if !(t_min <= f1.time_interval.0 && f1.time_interval.1 < t_max) {
	    n_not_in_time_interval1 += 1;
	    continue;
	}
	let f1_mp0 = outline_to_multipolygon(&f1.outline);
	let f1_area = f1_mp0.unsigned_area();
	if let Some(f1_mp) = clip_to_roi(&roi,&f1_mp0) {
	    let f1_mp_area = f1_mp.unsigned_area();
	    if f1_mp_area >= omega_min*f1_area {
		fps_in_roi1.push((i1,f1_mp,f1_mp_area));
		continue;
	    }
	} else {
	    trace!("Rejected {} as it does not meet the ROI",f1.id);
	}
	n_omega_too_low1 += 1;
    }

    for i2 in 0..n2 {
	let f2 = &fps2.footprints[i2];
	if !(t_min <= f2.time_interval.0 && f2.time_interval.1 < t_max) {
	    n_not_in_time_interval2 += 1;
	    continue;
	}

	let f2_mp0 = outline_to_multipolygon(&f2.outline);
	let f2_area = f2_mp0.unsigned_area();
	if let Some(f2_mp) = clip_to_roi(&roi,&f2_mp0) {
	    let f2_mp_area = f2_mp.unsigned_area();
	    if f2_mp_area >= omega_min*f2_area {
		fps_in_roi2.push((i2,f2_mp,f2_mp_area));
		continue;
	    }
	} else {
	    trace!("Rejected {} as it does not meet the ROI",f2.id);
	}
	n_omega_too_low2 += 1;
    }

    info!("Number of footprints in first file meeting the ROI: {} ({:5.2}%)",
	  fps_in_roi1.len(),
	  100.0*fps_in_roi1.len() as f64/n1 as f64);
    info!("  of which rejected due to not meeting the time interval: {}, low omega: {}",
	  n_not_in_time_interval1,
	  n_omega_too_low1);
    info!("Number of footprints in second file meeting the ROI: {} ({:5.2}%)",
	  fps_in_roi2.len(),
	  100.0*fps_in_roi2.len() as f64/n2 as f64);
    info!("  of which rejected due to not meeting the time interval: {}, low omega: {}",
	  n_not_in_time_interval2,
	  n_omega_too_low2);

    let mut n_pairs_tested = 0;
    let mut n_dist_too_large = 0;
    let mut n_delta_t_too_high = 0;
    let mut n_tau_too_low = 0;
    let mut n_psi_too_low = 0;
    let mut n_no_intersection = 0;
    let mut min_delta_t_stats = StatEstimator::new();
    let mut dist_stats = StatEstimator::new();

    let n_pairs_tot = fps_in_roi1.len()*fps_in_roi2.len();
    let mut prog = ProgressIndicator::new("Pairs",n_pairs_tot);

    for &(i1,ref f1_mp,f1_mp_area) in fps_in_roi1.iter() {
	let f1 = &fps1.footprints[i1];
	for &(i2,ref f2_mp,f2_mp_area) in fps_in_roi2.iter() {
	    let f2 = &fps2.footprints[i2];

	    n_pairs_tested += 1;
	    prog.update(n_pairs_tested);

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
	    min_delta_t_stats.add(min_delta_t);
	    
	    if min_delta_t <= delta_t_max {
		// Temporal overlap radio
		let tau =
		    if min_delta_t > 0.0 {
			0.0
		    } else {
			(f1.time_interval.1.min(f2.time_interval.1) - f1.time_interval.0.max(f2.time_interval.0)) /
			    (f1.time_interval.1.max(f2.time_interval.1) - f1.time_interval.0.min(f2.time_interval.0))
		    };
		if tau >= tau_min {
		    if let Some(c1) = f1_mp.centroid() {
			if let Some(c2) = f2_mp.centroid() {
			    let dist = Rhumb.distance(c1,c2);
			    dist_stats.add(dist);
			    if dist <= dist_max {
				if let Some((area,inter_mp)) = check_intersection(f1_mp,f2_mp) {
				    let psi = area / f1_mp_area.min(f2_mp_area);
				    if psi >= psi_min {
					let t0 = f1.time_interval.0.min(f2.time_interval.0);
					let t1 = f1.time_interval.1.max(f2.time_interval.1);
					let ts0 =
					    Utc.timestamp_opt(
						t0.floor() as i64,
						(t0.fract() * 1e9 + 0.5).floor() as u32)
					    .unwrap();
					let ts1 =
					    Utc.timestamp_opt(
						t1.floor() as i64,
						(t1.fract() * 1e9 + 0.5).floor() as u32)
					    .unwrap();
					trace!("F1 {:?} F2 {:?}",f1.time_interval,f2.time_interval);

					trace!("Intersection {:04}: {} vs {} (time difference {}, tau {}), psi: {}, time: {} to {}",
					       n_inter,f1.id,f2.id,min_delta_t,tau,psi,ts0,ts1);

					let rl = ReportLine {
					    n_inter,
					    ts:ts0, // XXX
					    min_delta_t,
					    tau,
					    psi,
					    id1:&f1.id,
					    lon1:c1.x(),
					    lat1:c1.y(),
					    id2:&f2.id,
					    lon2:c2.x(),
					    lat2:c2.y(),
					};
					report.add_line(&rl)?;

					if let Some(fp_fn) = args.value_of("output_base") {
					    let mut f1c = f1.clone();
					    let mut f2c = f2.clone();
					    let mut f1ci = f1.clone();
					    let mut f2ci = f2.clone();
					    let mut inter = f2.clone();
					    f1c.id = format!("FP1/{}/{}",n_inter,f1.id);
					    f2c.id = format!("FP2/{}/{}",n_inter,f2.id);
					    f1ci.id = format!("ROI1/{}/{}",n_inter,f1.id);
					    f2ci.id = format!("ROI2/{}/{}",n_inter,f2.id);
					    inter.id = format!("INT/{}/{}&{}",n_inter,f1.id,f2.id);
					    f1ci.outline = poly_utils::multipolygon_to_vec(f1_mp);
					    f2ci.outline = poly_utils::multipolygon_to_vec(f2_mp);
					    inter.outline = poly_utils::multipolygon_to_vec(&inter_mp);
					    let fps = Footprints{ footprints:vec![f1c,f2c,f1ci,f2ci,inter] };
					    fps.save_to_file(&format!("{}p{:06}.mpk",fp_fn,n_inter))?;
					}
					
					n_inter += 1;
					prog.set_label(&format!("Pairs (found: {})",n_inter));
				    } else {
					n_psi_too_low += 1;
				    }
				} else {
				    n_no_intersection += 1;
				    trace!("No intersection: {} vs {} (time difference {})",f1.id,f2.id,min_delta_t);

				    if save_no_inter {
					if let Some(fp_fn) = args.value_of("output_base") {
					    let mut f1c = f1.clone();
					    let mut f2c = f2.clone();
					    f1c.id = format!("FP1/{}",f1.id);
					    f2c.id = format!("FP2/{}",f2.id);
					    f1c.outline = poly_utils::multipolygon_to_vec(f1_mp);
					    f2c.outline = poly_utils::multipolygon_to_vec(f2_mp);
					    let fps = Footprints{ footprints:vec![f1c,f2c] };
					    fps.save_to_file(&format!("{}-no_inter-{:06}-{:06}.mpk",fp_fn,i1,i2))?;
					}
				    }
				}
			    } else {
				n_dist_too_large += 1;
				trace!("Rejected {} vs {} due to dist = {}",
				       f1.id,f2.id,dist);
			    }
			} else {
			    error!("Cannot compute FP2 centroid for {:04}",n_inter)
			}
		    } else {
			error!("Cannot compute FP1 centroid for {:04}",n_inter)
		    }
		} else {
		    n_tau_too_low += 1;
		    trace!("Rejected {} vs {} due to tau = {}",f1.id,f2.id,tau);
		}
	    } else {
		n_delta_t_too_high += 1;
		trace!("Rejected {} vs {} due to delta_t = {}",f1.id,f2.id,min_delta_t);
	    }
	}
    }
    info!("Number of pairs tested: {}",n_pairs_tested);
    info!("  ...rejected due to high delta t: {}",n_delta_t_too_high);
    info!("  ...rejected due to high dist: {}",n_dist_too_large);
    info!("  ...rejected due to lack of intersection: {}",n_no_intersection);
    info!("  ...rejected due to low tau: {}",n_tau_too_low);
    info!("  ...rejected due to low psi: {}",n_psi_too_low);
    info!("Number of intersections found: {}",n_inter);
    info!("Statistics:");
    info!("  ...min_delta_t {}",min_delta_t_stats);
    info!("  ...dist {}",dist_stats);
    
    Ok(())
}
