#![allow(dead_code)]
mod misc_error;
mod amcut;
mod poly_utils;

use std::error::Error;
use std::path::PathBuf;

use log::{info};
use chrono::{DateTime,NaiveDate,Duration,Utc};
use clap::{Arg,App};
use misc_error::MiscError;
use footprint::{Footprint,Footprints};
use ndarray::{ArrayD,Array1,Array2,Array4};
use std::collections::{BTreeMap,BTreeSet};
use hdf5_metno as hdf5;

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;
    let _ = hdf5::silence_errors(true);

    let args = App::new("tropomifpex")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("input").multiple(true))
	.arg(Arg::with_name("selection").long("selection").value_name("IGRA,ISCAN").multiple(true))
	.arg(Arg::with_name("scan0").long("scan0").takes_value(true).default_value("0").help("Zero-based index of first scan"))
	.arg(Arg::with_name("mscan").long("mscan").takes_value(true).default_value("1").help("Scan modulus"))
	.arg(Arg::with_name("nscan").long("nscan").takes_value(true).help("Number of scans"))
	.arg(Arg::with_name("by-pixel").short("p").long("by-pixel"))
	.get_matches();

    let out_fn = args.value_of("out").expect("Specify path to output file");
    let geo_fns = args.values_of("input").expect("Specify input files");
    let by_pixel = args.is_present("by-pixel");
    let with_selection = args.is_present("selection");
    let selection =
	if with_selection {
	    let mut sel = BTreeMap::new();
	    for (igra,ipix) in
		args
		.values_of("selection")
		.unwrap()
		.map(|x| {
		    let mut xs = x.split(',');
		    let x0 = xs.next().expect("No granule ID");
		    let x1 = xs.next().expect("No pixel ID");
		    (x0.parse::<usize>().expect("Bad granule ID"),
		     x1.parse::<usize>().expect("Bad pixel ID")) })
	    {
		sel.entry(igra).or_insert_with(|| BTreeSet::new()).insert(ipix);
	    }
	    Some(sel)
	} else {
	    None
	};

    let mut footprints = Vec::new();

    for geo_fn in geo_fns {
	info!("Processing file {}",geo_fn);
	let fd = hdf5::File::open(geo_fn)?;

	let geo_path = PathBuf::from(geo_fn);
	let dataset_id = MiscError::from_option(geo_path.file_stem(),"Cannot extract dataset name")?.to_string_lossy();
	info!("Dataset ID: {:?}",dataset_id);

	let gr = fd.group("/METADATA/EOP_METADATA/om:procedure/eop:instrument")?;
	let instrument : &hdf5::types::FixedAscii<16> = &gr.attr("eop:shortName")?.read_raw()?[0];
	info!("Instrument: {}",instrument);

	let gr = fd.group("/METADATA/EOP_METADATA/om:procedure/eop:platform")?;
	let platform : &hdf5::types::FixedAscii<16> = &gr.attr("eop:shortName")?.read_raw()?[0];
	info!("Platform: {}",platform);

	let orbit = fd.attr("orbit")?.read_raw::<i32>()?[0] as usize;
	info!("Orbit: {}",orbit);

	let lats_dyn : ArrayD<f32> = fd.dataset("/PRODUCT/SUPPORT_DATA/GEOLOCATIONS/latitude_bounds")?.read_dyn()?;
	let lat_dims = lats_dyn.dim();
	info!("Latitude bound dimensions: {:?}",lat_dims);
	let ngra = lat_dims[0];
	let nscan = lat_dims[1];
	let npix = lat_dims[2];
	let nvert = lat_dims[3];
	info!("Number of granules: {}",ngra);
	info!("Number of scans: {}",nscan);
	info!("Number of pixels: {}",npix);
	info!("Number of vertices: {}",nvert);
	let lats = lats_dyn.into_shape((ngra,nscan,npix,nvert))?;
	let lons : Array4<f32> = fd.dataset("/PRODUCT/SUPPORT_DATA/GEOLOCATIONS/longitude_bounds")?.read_dyn()?.into_shape((ngra,nscan,npix,nvert))?;
	info!("Getting granule base times");
	let times : Array1<i32> = fd.dataset("/PRODUCT/time")?.read_1d()?;
	info!("Getting scan delta times");
	let delta_times : Array2<i32> = fd.dataset("/PRODUCT/delta_time")?.read_2d()?;
	let tropomi_t0 = DateTime::<Utc>::from_utc(
	    NaiveDate::from_ymd_opt(2010,1,1)
		.unwrap()
		.and_hms_opt(0,0,0)
		.unwrap(),
	    Utc);

	let t_exp = 0.538306;
	// XXX this needs to be fetched from the exposure_time
	// field of the /BAND7_RADIANCE/STANDARD_MODE/INSTRUMENT/instrument_settings dataset

	let scan0 : usize = args.value_of("scan0").unwrap().parse().expect("Invalid scan index");
	let mscan : usize = args.value_of("mscan").unwrap().parse().expect("Invalid scan modulus");
	let nscan : usize =
	    if let Some(u) = args.value_of("nscan") {
		u.parse().expect("Invalid scan count")
	    } else {
		nscan
	    };

	let mut ncross = 0;

	let granules : Vec<usize> =
	    if let Some(ref sel) = selection {
		sel.keys().map(|&x| x).collect()
	    } else {
		(0..ngra).collect()
	    };

	for igra in granules {
	    let scans : Vec<usize> =
		if let Some(ref sel) = selection {
		    sel.get(&igra).unwrap().iter().map(|&x| x).collect()
		} else {
		    let mut scans = Vec::new();
		    let mut iscan = scan0;
		    loop {
			if iscan >= scan0+nscan {
			    break;
			}
			scans.push(iscan);
			iscan += mscan;
		    };
		    scans
		};
	    for iscan in scans {
		let t_obs = tropomi_t0 + Duration::seconds(times[[igra]] as i64) + Duration::milliseconds(delta_times[[igra,iscan]] as i64);
		let t0 = t_obs.timestamp_millis() as f64 / 1000.0;
		let t1 = t0 + t_exp;

		if by_pixel {
		    for ipix in 0..npix {
			let mut outline : Vec<Vec<Vec<(f64,f64)>>> = Vec::new();
			let mut ring = Vec::new();
			for i in (0..4).rev() {
			    ring.push((lons[[igra,iscan,ipix,i]] as f64,
				       lats[[igra,iscan,ipix,i]] as f64));
			}

			if amcut::cut_and_push(&mut outline,ring) {
			    ncross += 1;
			}
		    
			let id = format!("{}/{}/{}/{}",dataset_id,igra,iscan,ipix);
			let fp = Footprint{
			    orbit,
			    id:id.to_string(),
			    platform:platform.to_string(),
			    instrument:instrument.to_string(),
			    time_interval:(t0,t1),
			    outline
			};
			footprints.push(fp);
		    }
		} else {
		    let mut outline : Vec<Vec<Vec<(f64,f64)>>> = Vec::new();
		    let mut ring = Vec::new();
		    for ipix in 0..npix {
			ring.push((lons[[igra,iscan,ipix,0]] as f64,
				   lats[[igra,iscan,ipix,0]] as f64));
		    }
		    ring.push((lons[[igra,iscan,npix - 1,1]] as f64,
			       lats[[igra,iscan,npix - 1,1]] as f64));
		    for ipix in (0..npix).rev() {
			ring.push((lons[[igra,iscan,ipix,2]] as f64,
				   lats[[igra,iscan,ipix,2]] as f64));
		    }
		    ring.push((lons[[igra,iscan,0,3]] as f64,
			       lats[[igra,iscan,0,3]] as f64));

		    if amcut::cut_and_push(&mut outline,ring) {
			ncross += 1;
		    }
		    
		    let id = format!("{}/{}/{}",dataset_id,igra,iscan);
		    let fp = Footprint{
			orbit,
			id:id.to_string(),
			platform:platform.to_string(),
			instrument:instrument.to_string(),
			time_interval:(t0,t1),
			outline
		    };
		    footprints.push(fp);
		}
	    }
	}
	info!("Number of scan lines that have been split due to crossing the meridian boundary: {}",ncross);
    }
    let fps = Footprints{ footprints };
    fps.save_to_file(out_fn)?;
    Ok(())
}
