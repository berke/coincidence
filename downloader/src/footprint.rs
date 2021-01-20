#[derive(Debug,Clone)]
pub struct Footprint {
    pub orbit:usize,
    pub id:String,
    pub outline:Vec<Vec<Vec<(f64,f64)>>>
}

impl Footprint {
    pub fn new()->Self {
	Self{
	    orbit:0,
	    id:String::new(),
	    outline:Vec::new()
	}
    }

    pub fn clear(&mut self) {
	self.orbit = 0;
	self.id.clear();
	self.outline.clear();
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
}
