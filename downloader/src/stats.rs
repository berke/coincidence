use std::{
    fmt::{
	Display,
	Formatter,
	Error
    }
};

pub struct StatEstimator {
    n:usize,
    n_nan:usize,
    x0:f64,
    x1:f64,
    sx:f64
}

#[derive(Debug)]
pub struct Stats {
    pub n:usize,
    pub n_nan:usize,
    pub x0:f64,
    pub x1:f64,
    pub mu:f64
}

impl StatEstimator {
    pub fn new()->Self {
	Self { n:0,
	       n_nan:0,
	       x0:0.0,
	       x1:0.0,
	       sx:0.0 }
    }

    pub fn add(&mut self,x:f64) {
	if x.is_nan() {
	    self.n_nan += 1;
	} else {
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
    }

    pub fn stats(&self)->Stats {
	Stats {
	    n:self.n,
	    n_nan:self.n_nan,
	    x0:self.x0,
	    mu:self.sx/self.n as f64,
	    x1:self.x1
	}
    }
}

impl Display for StatEstimator
{
    fn fmt(&self,fmt:&mut Formatter)->Result<(),Error> {
	let Stats { n,n_nan,x0,mu,x1 } = self.stats();
	write!(fmt,"{:9.3e} [{:9.3e},{:9.3e}] n={},nan={}",
	       mu,
	       x0,
	       x1,
	       n,
	       n_nan)
    }
}
