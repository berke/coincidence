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

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;
    let _ = hdf5::silence_errors();

    let args = App::new("crispfex")
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

	let platform : &hdf5::types::FixedAscii<[u8;16]> = &fd.attribute("Platform_Short_Name")?.read_raw()?[0];
	info!("Platform: {}",platform);

	let iet_t0 = DateTime::<Utc>::from_utc(NaiveDate::from_ymd(1958,1,1).and_hms(0,0,0),Utc);

	let gr = fd.group("/Data_Products/CrIS-SDR-GEO")?;
	let instrument : &hdf5::types::FixedAscii<[u8;16]> = &gr.attribute("Instrument_Short_Name")?.read_raw()?[0];
	info!("Instrument: {}",instrument);

	for mem in gr.member_names()?.iter() {
	    trace!("Member: {}",mem);
	    let ds = gr.dataset(mem)?;
	    let mut outline = Vec::new();

	    if let Ok(at) = ds.attribute("G-Ring_Latitude") {
		let lats = at.read_2d::<f64>()?;
		let lons = ds.attribute("G-Ring_Longitude")?.read_2d::<f64>()?;
		let (m,_) = lats.dim();
		let mut ring = Vec::new();
		for i in 0..m {
		    ring.push((lats[[i,0]],lons[[i,0]]));
		}
		outline.push(vec![ring]);

		let t_start_iet = ds.attribute("N_Beginning_Time_IET")?.read_raw::<u64>()?[0];
		let t_end_iet = ds.attribute("N_Ending_Time_IET")?.read_raw::<u64>()?[0];
		trace!("Start: {}, end: {}",t_start_iet,t_end_iet);

		// Microseconds since Jan 1, 1958
		let t_start_epoch = iet_t0 + Duration::microseconds(t_start_iet as i64);
		let t_end_epoch = iet_t0 + Duration::microseconds(t_end_iet as i64);
		trace!("Epoch start: {}, end: {}",t_start_epoch,t_end_epoch);

		let t_start = t_start_epoch.timestamp_millis() as f64 / 1000.0;
		let t_end = t_end_epoch.timestamp_millis() as f64 / 1000.0;

		let orbit = ds.attribute("N_Beginning_Orbit_Number")?.read_raw::<u64>()?[0] as usize;
		trace!("Orbit: {}",orbit);

		let granule_id : &hdf5::types::FixedAscii<[u8;16]> = &ds.attribute("N_Granule_ID")?.read_raw()?[0];
		trace!("Granule ID: {}",granule_id);

		let id = format!("{}/{}",dataset_id,granule_id);

		let fp = Footprint{
		    orbit,
		    id:id.to_string(),
		    platform:platform.to_string(),
		    instrument:instrument.to_string(),
		    time_interval:(t_start,t_end),
		    outline
		};
		footprints.push(fp);
	    }
	}
    }
    let fps = Footprints{ footprints };
    fps.save_to_file(out_fn)?;
    Ok(())
}

