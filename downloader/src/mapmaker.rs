#![allow(dead_code)]
mod misc_error;
mod footprint;
mod minisvg;
mod amcut;
mod poly_utils;
mod fancy_footprint;

use std::error::Error;

use log::{info};
use clap::{Arg,App};
use fancy_footprint::FancyFootprints;
use ndarray::{Array1,Array2};
use geo::Point;
use geo::prelude::Contains;

fn sq(x:f64)->f64 { x*x }

pub struct Filter {
    pub mu:f64,
    pub sigma:f64,
    pub count:usize
}

impl Filter {
    pub fn new(mu:f64,sigma:f64)->Self {
	Self{ mu,sigma,count:0 }
    }

    pub fn add(&mut self,mu:f64,sigma:f64) {
	let alpha = sq(sigma) / (sq(self.sigma) + sq(sigma));
	self.mu = alpha*self.mu + (1.0 - alpha)*mu;
	self.sigma = (alpha*self.sigma).hypot((1.0 - alpha)*sigma);
	self.count += 1;
    }
}

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;
    let _ = hdf5::silence_errors();

    let args = App::new("mapmaker")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("ffp").short("f").long("ffp").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("lon0").long("lon0").default_value("62.0")
	     .help("Starting longitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lon1").long("lon1").default_value("82.0")
	     .help("Ending longitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lat0").long("lat0").default_value("53.0")
	     .help("Starting latitude of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("lat1").long("lat1").default_value("63.0")
	     .help("Ending latitude of ROI").allow_hyphen_values(true))
	// .arg(Arg::with_name("margin").long("margin").default_value("0.5")
	//      .help("Margin of ROI").allow_hyphen_values(true))
	.arg(Arg::with_name("mu_xch4").long("mu-xch4").default_value("1.85")
	     .help("Prior XCH4 mean (ppmv)").allow_hyphen_values(true))
	.arg(Arg::with_name("sigma_xch4").long("sigma-xch4").default_value("0.5")
	     .help("Prior XCH4 uncertainty (ppmv)").allow_hyphen_values(true))
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
    // let margin : f64 = args.value_of("margin").unwrap().parse().expect("Invalid margin");
    let nlat : usize = args.value_of("nlat").unwrap().parse().expect("Invalid number of latitude cells");
    let nlon : usize = args.value_of("nlon").unwrap().parse().expect("Invalid number of longitude cells");

    info!("Loading fancy footprints from {:?}",ffp_fn);
    let ffp = FancyFootprints::from_file(&ffp_fn)?;

    let dims = (nlat,nlon);
    info!("Creating {} by {} map",nlon,nlat);

    let mu_alt = 100.0;
    let sigma_alt_prior = 200.0;
    let sigma_alt = 5.0;

    let dlat = (lat1 - lat0) / (nlat - 1) as f64;
    let dlon = (lon1 - lon0) / (nlon - 1) as f64;
    let lats = Array1::from_shape_fn(
	nlat,
	|ilat| lat0 + ilat as f64 * dlat);
    let lons = Array1::from_shape_fn(
	nlon,
	|ilon| lon0 + ilon as f64 * dlon);

    let mut field = Array2::from_shape_fn(dims,|_| Filter::new(mu_xch4,sigma_xch4));
    let mut field_prior = Array2::from_shape_fn(dims,|_| Filter::new(mu_xch4,sigma_xch4));
    let mut field_tropomi = Array2::from_shape_fn(dims,|_| Filter::new(mu_xch4,sigma_xch4));
    let mut field_alt = Array2::from_shape_fn(dims,|_| Filter::new(mu_alt,sigma_alt_prior));

    for fp in ffp.footprints {
	if !fp.converged {
	    continue;
	}
	let pts = poly_utils::outline_points(&fp.fp.outline);
	let ((x0,x1),(y0,y1)) = poly_utils::bounding_box(&pts);
	let i0 = (((y0 - lat0) / dlat).floor().max(0.0) as usize).min(nlat - 1);
	let j0 = (((x0 - lon0) / dlon).floor().max(0.0) as usize).min(nlon - 1);
	let i1 = (((y1 - lat0) / dlat).ceil().max(0.0) as usize).min(nlat - 1);
	let j1 = (((x1 - lon0) / dlon).ceil().max(0.0) as usize).min(nlon - 1);
	let mp = poly_utils::outline_to_multipolygon(&fp.fp.outline);
	for ilon in j0..j1 {
	    for ilat in i0..i1 {
		let pt = Point::new(lons[ilon],lats[ilat]);
		if mp.contains(&pt) {
		    field[[ilat,ilon]].add(fp.xch4,fp.sigma_xch4);
		    field_tropomi[[ilat,ilon]].add(fp.xch4_tropomi,fp.sigma_xch4_tropomi);
		    field_prior[[ilat,ilon]].add(fp.xch4_prior,fp.sigma_xch4_prior);
		    field_alt[[ilat,ilon]].add(fp.alt,sigma_alt);
		}
	    }
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

    fn write_field(fd:&hdf5::File,
		   suffix:&str,
		   field:&Array2<Filter>)->Result<(),Box<dyn Error>> {
	let mu_xch4s = field.map(|f| f.mu);
	let sigma_xch4s = field.map(|f| f.sigma);
	let counts = field.map(|f| f.count);
	wrg2(fd,&format!("xch4{}",suffix),&mu_xch4s)?;
	wrg2(fd,&format!("sigma_xch4{}",suffix),&sigma_xch4s)?;
	wrg2(fd,&format!("count{}",suffix),&counts)?;
	Ok(())
    }

    let fd = hdf5::File::create(out_fn)?;
    wrg1(&fd,"lats",&lats)?;
    wrg1(&fd,"lons",&lons)?;
    write_field(&fd,"",&field)?;
    write_field(&fd,"_prior",&field_prior)?;
    write_field(&fd,"_tropomi",&field_tropomi)?;
    let mu_alts = field_alt.map(|f| f.mu);
    wrg2(&fd,"alts",&mu_alts)?;
    Ok(())
}
