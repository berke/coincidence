use std::error::Error;
use std::path::Path;
use std::fs::File;
use std::io::{BufReader,BufWriter};
use serde::{Serialize,Deserialize};
use serde_json::{Map,to_value};
use footprint::{Footprint,FootprintLike};

#[derive(Debug,Clone,Serialize,Deserialize)]
pub struct FancyFootprint {
    pub fp:Footprint,
    pub xch4:f64,
    pub sigma_xch4:f64,
    pub xch4_prior:f64,
    pub sigma_xch4_prior:f64,
    pub xch4_tropomi:f64,
    pub sigma_xch4_tropomi:f64,
    pub t_unix:f64,
    pub t_unix_tropomi:f64,
    pub lat:f64,
    pub lon:f64,
    pub alt:f64,
    pub lat_tropomi:f64,
    pub lon_tropomi:f64,
    pub converged:bool,
    pub chi2:f64
}

#[derive(Debug,Clone,Serialize,Deserialize)]
pub struct FancyFootprints {
    pub footprints:Vec<FancyFootprint>
}

impl FootprintLike for FancyFootprint {
    fn orbit(&self)->usize { self.fp.orbit() }
    fn id(&self)->&str { self.fp.id() }
    fn platform(&self)->&str { self.fp.platform() }
    fn instrument(&self)->&str { self.fp.instrument() }
    fn time_interval(&self)->(f64,f64) { self.fp.time_interval() }
    fn outline(&self)->&Vec<Vec<Vec<(f64,f64)>>> { self.fp.outline() }
    fn properties(&self)->Map<String,serde_json::Value> {
	let mut map = Map::new();
	map.insert(String::from("xch4"),to_value(self.xch4).unwrap());
	map.insert(String::from("sigma_xch4"),to_value(self.sigma_xch4).unwrap());
	map.insert(String::from("xch4_prior"),to_value(self.xch4_prior).unwrap());
	map.insert(String::from("sigma_xch4_prior"),to_value(self.sigma_xch4_prior).unwrap());
	map.insert(String::from("xch4_tropomi"),to_value(self.xch4_tropomi).unwrap());
	map.insert(String::from("sigma_xch4_tropomi"),to_value(self.sigma_xch4_tropomi).unwrap());
	map.insert(String::from("t_unix"),to_value(self.t_unix).unwrap());
	map.insert(String::from("t_unix_tropomi"),to_value(self.t_unix_tropomi).unwrap());
	map.insert(String::from("lat"),to_value(self.lat).unwrap());
	map.insert(String::from("lon"),to_value(self.lon).unwrap());
	map.insert(String::from("alt"),to_value(self.alt).unwrap());
	map.insert(String::from("lat_tropomi"),to_value(self.lat_tropomi).unwrap());
	map.insert(String::from("lon_tropomi"),to_value(self.lon_tropomi).unwrap());
	map.insert(String::from("converged"),to_value(self.converged).unwrap());
	map.insert(String::from("chi2"),to_value(self.chi2).unwrap());
	map
    }
}

impl FancyFootprints {
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
}
