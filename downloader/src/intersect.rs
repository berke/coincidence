#![allow(dead_code)]

mod progress;
mod common;
mod report;
mod stats;

use common::*;

fn locate<P,Q>(paths:&[P],name:Q,ext:&str)->Result<PathBuf>
where P:AsRef<Path>,Q:AsRef<Path>
{
    let mut pb = PathBuf::new();
    for base in paths {
        pb.clear();
        pb.push(&base);
        pb.push(&name);
        pb.add_extension(ext);
        if pb.exists() {
            return Ok(pb);
        }
    }
    bail!("File {:?} not found in any path",name.as_ref())
}

fn timestamp_from_str(u:&str)->Result<f64> {
    let ndt : NaiveDateTime =
        NaiveDateTime::parse_from_str(u,"%Y-%m-%dT%H:%M:%S")?;
    let ts : DateTime<_> = Utc.from_utc_datetime(&ndt);
    Ok(ts.timestamp_millis() as f64 / 1000.0)
}

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

fn main()->Result<()> {
    let mut args = Arguments::from_env();
    let verbose = args.contains("--verbose");
    let trace = args.contains("--trace");
    let debug = args.contains("--debug");
    let data_paths : Vec<OsString> = args.values_from_str("--data-path")?;
    let input_path : OsString = args.value_from_str("--input")?;
    let output_base : Option<OsString> = args.opt_value_from_str("--output-base")?;
    let report_fn : OsString = args.value_from_str("--report")?;
    let dist_max : f64 = args.opt_value_from_str("--dist-max")?.unwrap_or(1e4);
    let t_min : f64 = args.opt_value_from_fn("--t-min",timestamp_from_str)?
        .unwrap_or(0.0);
    let t_max : f64 = args.opt_value_from_fn("--t-max",timestamp_from_str)?
        .unwrap_or(f64::INFINITY);
    let delta_t_max : f64 = args.opt_value_from_str("--delta-t-max")?
        .unwrap_or(13200.0);
    let tau_min : f64 = args.opt_value_from_str("--tau-min")?.unwrap_or(0.0);
    let psi_min : f64 = args.opt_value_from_str("--psi-min")?.unwrap_or(0.50);
    let omega_min : f64 = args.opt_value_from_str("--omega-min")?.unwrap_or(0.0);
    let lon0 : f64 = args.opt_value_from_str("--lon0")?.unwrap_or(-180.0);
    let lon1 : f64 = args.opt_value_from_str("--lon1")?.unwrap_or(180.0);
    let lat0 : f64 = args.opt_value_from_str("--lat0")?.unwrap_or(-90.0);
    let lat1 : f64 = args.opt_value_from_str("--lat1")?.unwrap_or(90.0);
    let save_no_inter = args.contains("--save-no-inter");

    simple_logger::SimpleLogger::new()
        .with_level(
            if trace { log::LevelFilter::Trace }
            else if debug { log::LevelFilter::Debug }
            else if verbose { log::LevelFilter::Info }
            else { log::LevelFilter::Warn })
        .init()?;

    info!("Loading coincidence file from {:?}",input_path);
    let coin = Coincidence::load(&input_path)?;

    info!("Comparing {} vs {}",coin.name1,coin.name2);
    let fp1_fn = locate(&data_paths,coin.name1,"mpk")?;
    let fp2_fn = locate(&data_paths,coin.name2,"mpk")?;

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

    info!("Loading first set of footprints from {:?}",fp1_fn);
    let fps1 = Footprints::from_file(fp1_fn)?;
    let n1 = fps1.footprints.len();

    info!("Loading second set of footprints from {:?}",fp2_fn);
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

    let mut fps_in_roi1 = HashMap::new();
    let mut fps_in_roi2 = HashMap::new();

    let mut midp = MeasIdParser::new()?;

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
                let mid1 = midp.parse(&f1.id)?;
                let idx : Index = mid1.index.try_into()?;
                fps_in_roi1.insert(idx,(i1,f1_mp,f1_mp_area));
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
                let mid2 = midp.parse(&f2.id)?;
                let idx : Index = mid2.index.try_into()?;
                fps_in_roi2.insert(idx,(i2,f2_mp,f2_mp_area));
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

    let mut nidx1_not_found = 0;
    let mut nidx2_not_found = 0;
    for (p1,p2) in &coin.pairs {
        for idx1 in p1 {
            if let Some(&(i1,ref f1_mp,f1_mp_area)) = fps_in_roi1.get(&idx1) {
                let f1 = &fps1.footprints[i1];
                for idx2 in p2 {
                    if let Some(&(i2,ref f2_mp,f2_mp_area)) = fps_in_roi2.get(&idx2) {
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

					            if let Some(ref fp_fn) = output_base {
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
                                                        let mut pb : PathBuf = fp_fn.into();
					                pb.push(format!("p{:06}.mpk",n_inter));
					                fps.save_to_file(&pb)?;
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
					            if let Some(ref fp_fn) = output_base {
					                let mut f1c = f1.clone();
					                let mut f2c = f2.clone();
					                f1c.id = format!("FP1/{}",f1.id);
					                f2c.id = format!("FP2/{}",f2.id);
					                f1c.outline = poly_utils::multipolygon_to_vec(f1_mp);
					                f2c.outline = poly_utils::multipolygon_to_vec(f2_mp);
					                let fps = Footprints{ footprints:vec![f1c,f2c] };
                                                        let mut pb : PathBuf = fp_fn.into();
                                                        pb.push(format!("no_inter-{:06}-{:06}.mpk",i1,i2));
                                                        fps.save_to_file(&pb)?;
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

                    } else {
                        nidx2_not_found += 1;
                    }
                }
            } else {
                nidx1_not_found += 1;
            }
        }
    }
    info!("Number of indices not found: {}, {}",
          nidx1_not_found,
          nidx2_not_found);

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
