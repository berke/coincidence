#![allow(dead_code)]

mod misc_error;
mod minisvg;
mod footprint;

use std::error::Error;
use log::info;
use clap::{Arg,App};
use chrono::{Utc,TimeZone};
use footprint::Footprints;

struct Stats {
    n:usize,
    x0:f64,
    x1:f64,
    sx:f64
}

impl Stats {
    pub fn new()->Self {
	Self{ n:0,
	      x0:0.0,
	      x1:0.0,
	      sx:0.0 }
    }

    pub fn add(&mut self,x:f64) {
	if self.n == 0 {
	    self.x0 = x;
	    self.x1 = x;
	} else {
	    self.x0 = self.x0.min(x);
	    self.x1 = self.x1.max(x);
	}
	self.n += 1;
	self.sx += x;
    }

    pub fn summary(&self)->(f64,f64,f64) {
	(self.x0,self.sx/self.n as f64,self.x1)
    }
}

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;

    let args = App::new("fptool")
	.arg(Arg::with_name("input").multiple(true))
	.arg(Arg::with_name("concat").short("c").takes_value(true))
	.arg(Arg::with_name("draw").short("d").takes_value(true))
	.get_matches();

    let mut footprints = Vec::new();

    let mut lat_stats = Stats::new();
    let mut lon_stats = Stats::new();

    let fp_fns = args.values_of("input").expect("Specify footprint files");
    for fp_fn in fp_fns {
	info!("Footprint file {}",fp_fn);
	let fps = Footprints::from_file(fp_fn)?;
	let m = fps.footprints.len();
	info!("Number of footprints: {}",m);
	for i in 0..m{
	    let fp = &fps.footprints[i];
	    let (t0,t1) = fp.time_interval;
	    let ts0 = Utc.timestamp(t0.floor() as i64,(t0.fract() * 1e9 + 0.5).floor() as u32);
	    let ts1 = Utc.timestamp(t1.floor() as i64,(t1.fract() * 1e9 + 0.5).floor() as u32);
	    info!("Time: {} to {}",ts0,ts1);
	    info!("Orbit: {}",fp.orbit);
	    info!("Platform: {}",fp.platform);
	    info!("Instrument: {}",fp.instrument);
	    info!("ID: {}",fp.id);
	    for poly in fp.outline.iter() {
		for ring in poly.iter() {
		    for &(lon,lat) in ring.iter() {
			lon_stats.add(lon);
			lat_stats.add(lat);
		    }
		}
	    }
	    footprints.push(fp.clone());
	}
    }
    let (lon0,lon_mean,lon1) = lon_stats.summary();
    let (lat0,lat_mean,lat1) = lat_stats.summary();
    info!("Longitude range: {} to {}, mean {}",lon0,lon1,lon_mean);
    info!("Latitude range: {} to {}, mean {}",lat0,lat1,lat_mean);

    let fps = Footprints{ footprints };
    if let Some(draw_fn) = args.value_of("draw") {
	fps.draw(draw_fn)?;
    }

    if let Some(path) = args.value_of("concat") {
	let m = fps.footprints.len();
	info!("Saving {} footprints to {}",m,path);
	fps.save_to_file(path)?;
    }

    Ok(())
}
