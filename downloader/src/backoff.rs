#[derive(Clone)]
pub struct BackoffParams {
    t_start:f64,
    t_max:f64,
    scale:f64
}

impl Default for BackoffParams {
    fn default()->Self {
	Self {
	    t_start:1.0,
	    t_max:600.0,
	    scale:5.0,
	}
    }
}

pub struct Backoff {
    params:BackoffParams,
    current:f64,
}

impl Backoff {
    pub fn new(params:BackoffParams)->Self {
	let current = params.t_start;
	Self {
	    params,
	    current
	}
    }

    pub fn success(&mut self) {
	self.current = self.params.t_start;
    }

    pub async fn failure(&mut self) {
	let d = std::time::Duration::from_secs_f64(self.current);
	tokio::time::sleep(d).await;
	// std::thread::sleep(std::time::Duration::from_secs_f64(self.current));
	self.current = (self.current * self.params.scale)
	    .min(self.params.t_max);
    }
}
