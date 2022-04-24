#![allow(dead_code)]
mod misc_error;
mod footprint;
mod minisvg;
mod amcut;
mod poly_utils;
mod fancy_footprint;

use std::error::Error;
use std::ffi::OsString;
use std::path::PathBuf;

use log::{error,info};
use clap::{Arg,App};
use misc_error::MiscError;
use fancy_footprint::FancyFootprints;
use ndarray::{s,Array1,Array2};
use std::collections::{BTreeMap,BTreeSet};
use serde_json::{Map,to_value};

fn sq(x:f64)->f64 { x*x }

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;
    let _ = hdf5::silence_errors();

    let args = App::new("mapmaker")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("ffp").short("f").long("ffp").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("lon0").long("lon0").default_value("-5.0")
	     .help("Starting longitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lon1").long("lon1").default_value("9.0")
	     .help("Ending longitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lat0").long("lat0").default_value("42.0")
	     .help("Starting latitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lat1").long("lat1").default_value("52.0")
	     .help("Ending latitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("margin").long("margin").default_value("0.5")
	     .help("Margin of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("mu_xch4").long("mu-xch4").default_value("1850.0")
	     .help("Prior XCH4 mean (ppbv)").allow_hyphen_values(true))
	.arg(Arg::with_name("sigma_xch4").long("sigma-xch4").default_value("500.0")
	     .help("Prior XCH4 uncertainty (ppbv)").allow_hyphen_values(true))
	.arg(Arg::with_name("nlat").long("nlat").default_value("256")
	     .help("Number of latitude cells"))
	.arg(Arg::with_name("nlon").long("nlon").default_value("256")
	     .help("Number of longitude cells"))
	.get_matches();

    let out_fn = args.value_of("out").expect("Specify output filename");
    let ffp_fn = args.value_of("ffp").expect("Specify fancy footprints");

    let sigma_xch4 : f64 = args.value_of("sigma_xch4").unwrap().parse().expect("Invalid sigma_xch4");
    let mu_xch4 : f64 = args.value_of("mu_xch4").unwrap().parse().expect("Invalid mu_xch4");
    let lon0 : f64 = args.value_of("lon0").unwrap().parse().expect("Invalid starting longitude");
    let lat0 : f64 = args.value_of("lat0").unwrap().parse().expect("Invalid starting latitude");
    let lon1 : f64 = args.value_of("lon1").unwrap().parse().expect("Invalid ending longitude");
    let lat1 : f64 = args.value_of("lat1").unwrap().parse().expect("Invalid ending latitude");
    let margin : f64 = args.value_of("margin").unwrap().parse().expect("Invalid margin");
    let nlat : usize = args.value_of("nlat").unwrap().parse().expect("Invalid number of latitude cells");
    let nlon : usize = args.value_of("nlon").unwrap().parse().expect("Invalid number of longitude cells");

    info!("Loading fancy footprints from {:?}",ffp_fn);
    let ffp = FancyFootprints::from_file(&ffp_fn)?;

    let dims = (nlat,nlon);
    info!("Creating {} by {} map",nlon,nlat);

    let dlat = (lat1 - lat0) / (nlat - 1) as f64;
    let dlon = (lon1 - lon0) / (nlon - 1) as f64;
    let lats = Array1::from_shape_fn(
	nlat,
	|ilat| lat0 + ilat as f64 * dlat);
    let lons = Array1::from_shape_fn(
	nlon,
	|ilon| lon0 + ilon as f64 * dlon);

    let mut mu_xch4s = Array2::from_elem(dims,mu_xch4);
    let mut sigma_xch4s = Array2::from_elem(dims,sigma_xch4);

    for fp in ffp.footprints {
	let ilatf = (fp.lat - lat0) / dlat;
	let ilonf = (fp.lon - lon0) / dlon;
	if 0.0 <= ilatf && ilatf < nlat as f64
	    && 0.0 <= ilonf && ilonf < nlon as f64 {
		let ilat = ilatf as usize;
		let ilon = ilonf as usize;
		let idx = [ilat,ilon];
		let sigma1 = sigma_xch4s[idx];
		let sigma2 = fp.sigma_xch4;
		let alpha = sq(sigma2) / (sq(sigma1) + sq(sigma2));
		mu_xch4s[idx] = alpha*mu_xch4s[idx] + (1.0 - alpha)*fp.xch4;
		sigma_xch4s[idx] = (alpha*sigma1).hypot((1.0 - alpha)*sigma2);
	    }
    }

    fn wrg1<T:hdf5::H5Type>(fd:&hdf5::File,
			    name:&str,arr:&Array1<T>)->Result<(),Box<dyn Error>> {
	fd.new_dataset::<T>().create(name,arr.dim())?.write(arr.view())?;
	Ok(())
    }

    fn wrg2<T:hdf5::H5Type>(fd:&hdf5::File,
			    name:&str,arr:&Array2<T>)->Result<(),Box<dyn Error>> {
	fd.new_dataset::<T>().create(name,arr.dim())?.write(arr.view())?;
	Ok(())
    }

    let fd = hdf5::File::create(out_fn)?;
    wrg1(&fd,"lats",&lats)?;
    wrg1(&fd,"lons",&lons)?;
    wrg2(&fd,"xch4",&mu_xch4s)?;
    wrg2(&fd,"sigma_xch4",&sigma_xch4s)?;
    Ok(())
}
