#![allow(dead_code)]
mod misc_error;
mod footprint;
mod minisvg;

use std::error::Error;
use std::path::PathBuf;

use log::{info,trace};
use chrono::{DateTime,NaiveDate,Duration,Utc};
use clap::{Arg,App};
use misc_error::MiscError;
use footprint::{Footprint,Footprints};
use ndarray::{ArrayD,Array1,Array2,Array3,Array4};

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;
    let _ = hdf5::silence_errors();

    let args = App::new("tropomifpex")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("input").multiple(true))
	.get_matches();

    let out_fn = args.value_of("out").expect("Specify path to output file");
    let geo_fns = args.values_of("input").expect("Specify input files");

    let mut footprints = Vec::new();

    for geo_fn in geo_fns {
	info!("Processing file {}",geo_fn);
	let fd = hdf5::File::open(geo_fn)?;

	let geo_path = PathBuf::from(geo_fn);
	let dataset_id = MiscError::from_option(geo_path.file_stem(),"Cannot extract dataset name")?.to_string_lossy();
	info!("Dataset ID: {:?}",dataset_id);

	let gr = fd.group("/METADATA/EOP_METADATA/om:procedure/eop:instrument")?;
	let instrument : &hdf5::types::FixedAscii<[u8;16]> = &gr.attribute("eop:shortName")?.read_raw()?[0];
	info!("Instrument: {}",instrument);

	let gr = fd.group("/METADATA/EOP_METADATA/om:procedure/eop:platform")?;
	let platform : &hdf5::types::FixedAscii<[u8;16]> = &gr.attribute("eop:shortName")?.read_raw()?[0];
	info!("Platform: {}",platform);

	let orbit = fd.attribute("orbit")?.read_raw::<i32>()?[0] as usize;
	info!("Orbit: {}",orbit);

	let lats_dyn : ArrayD<f32> = fd.dataset("/BAND7_RADIANCE/STANDARD_MODE/GEODATA/latitude_bounds")?.read_dyn()?;
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
	let lons : Array4<f32> = fd.dataset("/BAND7_RADIANCE/STANDARD_MODE/GEODATA/longitude_bounds")?.read_dyn()?.into_shape((ngra,nscan,npix,nvert))?;
	info!("Getting granule base times");
	let times : Array1<i32> = fd.dataset("/BAND7_RADIANCE/STANDARD_MODE/OBSERVATIONS/time")?.read_1d()?;
	info!("Getting scan delta times");
	let delta_times : Array2<i32> = fd.dataset("/BAND7_RADIANCE/STANDARD_MODE/OBSERVATIONS/delta_time")?.read_2d()?;
	let tropomi_t0 = DateTime::<Utc>::from_utc(NaiveDate::from_ymd(2010,1,1).and_hms(0,0,0),Utc);
	let t_exp = 1e-3; // XXX

	for igra in 0..ngra {
	    for iscan in 0..nscan {
		let mut outline = Vec::new();
		let mut poly = Vec::new();
		for ipix in 0..npix {
		    let mut ring = Vec::new();
		    for ivert in 0..nvert {
			ring.push((lats[[igra,iscan,ipix,ivert]] as f64,
			           lons[[igra,iscan,ipix,ivert]] as f64));
		    }
		    poly.push(ring);
		}
		outline.push(poly);
		let t_obs = tropomi_t0 + Duration::seconds(times[[igra]] as i64) + Duration::milliseconds(delta_times[[igra,iscan]] as i64);
		let t0 = t_obs.timestamp_millis() as f64 / 1000.0;
		let t1 = t0 + t_exp;
		let id = format!("{}/{}",dataset_id,igra);
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

	// let dataset_id = MiscError::from_option(geo_path.file_stem(),"Cannot extract dataset name")?.to_string_lossy();
	// info!("Dataset ID: {:?}",dataset_id);

	// let platform : &hdf5::types::FixedAscii<[u8;16]> = &fd.attribute("Platform_Short_Name")?.read_raw()?[0];
	// info!("Platform: {}",platform);

	// let iet_t0 = DateTime::<Utc>::from_utc(NaiveDate::from_ymd(1958,1,1).and_hms(0,0,0),Utc);

	// let gr = fd.group("/Data_Products/CrIS-SDR-GEO")?;
	// let instrument : &hdf5::types::FixedAscii<[u8;16]> = &gr.attribute("Instrument_Short_Name")?.read_raw()?[0];
	// info!("Instrument: {}",instrument);

	// for mem in gr.member_names()?.iter() {
	//     trace!("Member: {}",mem);
	//     let ds = gr.dataset(mem)?;
	//     let mut outline = Vec::new();

	//     if let Ok(at) = ds.attribute("G-Ring_Latitude") {
	// 	let lats = at.read_2d::<f64>()?;
	// 	let lons = ds.attribute("G-Ring_Longitude")?.read_2d::<f64>()?;
	// 	let (m,_) = lats.dim();
	// 	let mut ring = Vec::new();
	// 	for i in 0..m {
	// 	    ring.push((lats[[i,0]],lons[[i,0]]));
	// 	}
	// 	outline.push(vec![ring]);

	// 	let t_start_iet = ds.attribute("N_Beginning_Time_IET")?.read_raw::<u64>()?[0];
	// 	let t_end_iet = ds.attribute("N_Ending_Time_IET")?.read_raw::<u64>()?[0];
	// 	trace!("Start: {}, end: {}",t_start_iet,t_end_iet);

	// 	// Microseconds since Jan 1, 1958
	// 	let t_start_epoch = iet_t0 + Duration::microseconds(t_start_iet as i64);
	// 	let t_end_epoch = iet_t0 + Duration::microseconds(t_end_iet as i64);
	// 	trace!("Epoch start: {}, end: {}",t_start_epoch,t_end_epoch);

	// 	let t_start = t_start_epoch.timestamp_millis() as f64 / 1000.0;
	// 	let t_end = t_end_epoch.timestamp_millis() as f64 / 1000.0;

	// 	let orbit = ds.attribute("N_Beginning_Orbit_Number")?.read_raw::<u64>()?[0] as usize;
	// 	trace!("Orbit: {}",orbit);

	// 	let granule_id : &hdf5::types::FixedAscii<[u8;16]> = &ds.attribute("N_Granule_ID")?.read_raw()?[0];
	// 	trace!("Granule ID: {}",granule_id);

	// 	let id = format!("{}/{}",dataset_id,granule_id);

	// 	let fp = Footprint{
	// 	    orbit,
	// 	    id:id.to_string(),
	// 	    platform:platform.to_string(),
	// 	    instrument:instrument.to_string(),
	// 	    time_interval:(t_start,t_end),
	// 	    outline
	// 	};
	// 	footprints.push(fp);
	//     }
	// }
    }
    let fps = Footprints{ footprints };
    fps.save_to_file(out_fn)?;
    Ok(())
}
