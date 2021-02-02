use std::error::Error;
use std::path::Path;
use std::fs::File;
use std::io::{BufReader,BufWriter};
use serde::{Serialize,Deserialize};
use chrono::{Utc,TimeZone};

use crate::minisvg::MiniSVG;

#[derive(Debug,Clone,Serialize,Deserialize)]
pub struct Footprint {
    pub orbit:usize,
    pub id:String,
    pub platform:String,
    pub instrument:String,
    pub time_interval:(f64,f64),
    pub outline:Vec<Vec<Vec<(f64,f64)>>> // (longitude,latitude) pairs
}

impl Footprint {
    pub fn new()->Self {
	Self{
	    orbit:0,
	    id:String::new(),
	    platform:String::new(),
	    instrument:String::new(),
	    time_interval:(0.0,0.0),
	    outline:Vec::new()
	}
    }

    pub fn mean_time(&self)->f64 {
	(self.time_interval.0 + self.time_interval.1) / 2.0
    }

    pub fn min_coords(&self)->(f64,f64) {
	self.outline.iter().fold(
	    (std::f64::INFINITY,std::f64::INFINITY),
	    |curr,poly|
	    poly.iter().fold(curr,
			     |curr2,ring|
			     ring.iter().fold(
				 curr2,
				 |(lon0,lat0),&(lon,lat)| (lon0.min(lon),lat0.min(lat)))))
    }

    pub fn max_coords(&self)->(f64,f64) {
	self.outline.iter().fold(
	    (std::f64::NEG_INFINITY,std::f64::NEG_INFINITY),
	    |curr,poly|
	    poly.iter().fold(curr,
			     |curr2,ring|
			     ring.iter().fold(
				 curr2,
				 |(lon0,lat0),&(lon,lat)| (lon0.max(lon),lat0.max(lat)))))
    }
}

#[derive(Debug,Clone,Serialize,Deserialize)]
pub struct Footprints {
    pub footprints:Vec<Footprint>
}

impl Footprints {
    pub fn from_file<P:AsRef<Path>>(path:P)->Result<Self,Box<dyn Error>> {
	let fd = File::open(path)?;
	let mut buf = BufReader::new(fd);
	let fps : Self = rmp_serde::decode::from_read(&mut buf)?;
	Ok(fps)
    }

    pub fn save_to_file<P:AsRef<Path>>(&self,path:P)->Result<(),Box<dyn Error>> {
	let fd = File::create(path)?;
	let mut buf = BufWriter::new(fd);
	self.serialize(&mut rmp_serde::Serializer::new(&mut buf))?;
	Ok(())
    }

    pub fn draw<P:AsRef<Path>>(&self,path:P)->Result<(),Box<dyn Error>> {
	let Footprints{ footprints } = self;
	// let n_footprint = footprints.len();
	// println!("Number of footprints found: {}",n_footprint);
	let mut ms = MiniSVG::new(path,360.0,180.0,-180.0,-90.0)?;
	for fp in footprints.iter() {
	    // println!("Orbit: {}",f.orbit);
	    // println!("ID: {}",f.id);
	    // for a in f.outline.iter() {
	    // 	// let mp : Vec<Vec<(f64,f64)>> =
	    // 	//     a.iter().map(|b| {
	    // 	// 	let c : Vec<(f64,f64)> = b.iter().map(|(x,y)| (x,y)).collect();
	    // 	// 	c }).collect();
	    // 	ms.polygon(&mp)?;
	    // }
	    ms.set_stroke(Some((0xff0000,0.01,1.0)));
	    ms.set_fill(Some((0xffff80,0.25)));
	    ms.multi_polygon(&fp.outline)?;
	    let (lon0,lat0) = fp.max_coords();
	    let t = fp.mean_time();
	    let ts = Utc.timestamp(t.floor() as i64,(t.fract() * 1e9 + 0.5).floor() as u32);
	    let tss = ts.format("%H:%M");
	    ms.set_fill(Some((0x000000,1.00)));
	    ms.text(lon0,lat0,0.2,&tss.to_string())?;
	}
	Ok(())
    }
}
