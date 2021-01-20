#[derive(Debug,Clone)]
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

    pub fn clear(&mut self) {
	self.orbit = 0;
	self.id.clear();
	self.outline.clear();
	self.time_interval = (0.0,0.0);
    }

    pub fn set_orbit(&mut self,orbit:usize) {
	self.orbit = orbit;
    }

    pub fn set_outline(&mut self,outline:&Vec<Vec<Vec<(f64,f64)>>>) {
	self.outline = outline.to_vec();
    }

    pub fn set_id(&mut self,id:&str) {
	self.id = id.to_string();
    }

    pub fn set_time_interval(&mut self,t:(f64,f64)) {
	self.time_interval = t;
    }
}
