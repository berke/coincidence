use serde::{Serialize,Deserialize};

#[derive(Debug,Clone,Serialize,Deserialize)]
pub struct Footprint {
    pub orbit:usize,
    pub id:String,
    pub platform:String,
    pub instrument:String,
    pub time_interval:(f64,f64),
    pub outline:Vec<Vec<Vec<(f64,f64)>>>
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
}

#[derive(Debug,Clone,Serialize,Deserialize)]
pub struct Footprints {
    pub footprints:Vec<Footprint>
}
