mod misc_error;
mod minisvg;

use std::error::Error;
use log::{error,info,trace};
use misc_error::MiscError;
use ndarray::{s,Array2,ArrayD,AsArray,ArrayView2};
use chrono::{Datelike,DateTime,NaiveDate,NaiveDateTime,Duration,SecondsFormat,Utc,TimeZone};
use minisvg::MiniSVG;

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;
    let _ = hdf5::silence_errors();
    let geo_fn = MiscError::from_option(std::env::args().nth(1),"Specify path to geo file")?;
    info!("Loading footprint information from file {}",geo_fn);
    let fd = hdf5::File::open(geo_fn)?;

    let mut msvg = MiniSVG::new("out.svg",360.0,180.0,-180.0,-90.0)?;
    msvg.set_stroke(Some((0xff0000,0.1,0.1)));

    let iet_t0 = DateTime::<Utc>::from_utc(NaiveDate::from_ymd(1958,1,1).and_hms(0,0,0),Utc);

    let gr = fd.group("/Data_Products/CrIS-SDR-GEO")?;
    for mem in gr.member_names()?.iter() {
	trace!("Member: {}",mem);
	let ds = gr.dataset(mem)?;
	if let Ok(at) = ds.attribute("G-Ring_Latitude") {
	    let lats = at.read_2d::<f64>()?;
	    let lons = ds.attribute("G-Ring_Longitude")?.read_2d::<f64>()?;
	    let (m,_) = lats.dim();
	    let mut poly = Vec::new();
	    for i in 0..m {
		poly.push((lats[[i,0]],lons[[i,0]]));
	    }
	    msvg.polygon(&vec![poly])?;

	    let t_start = ds.attribute("N_Beginning_Time_IET")?.read_2d::<u64>()?;
	    let t_end = ds.attribute("N_Ending_Time_IET")?.read_2d::<u64>()?;
	    let t_start = t_start[[0,0]];
	    let t_end = t_end[[0,0]];

	    // Microseconds since Jan 1, 1958
	    trace!("Start: {}, end: {}",t_start,t_end);
	    let t_start_epoch = iet_t0 + Duration::microseconds(t_start as i64);
	    let t_end_epoch = iet_t0 + Duration::microseconds(t_end as i64);
	    trace!("Epoch start: {}, end: {}",t_start_epoch,t_end_epoch);

	    let id : &hdf5::types::FixedAscii<[u8;16]> = &ds.attribute("N_Granule_ID")?.read_raw()?[0];
	    // let id = &id[0];
	    trace!("Granule ID: {}",id);
	}
    }
    Ok(())
}

