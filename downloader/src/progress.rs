// use log::info;

pub struct ProgressIndicator {
    total:usize,
    current:usize,
    last:usize,
    rate:f64,
    t_first:f64,
    t_prev:f64,
    t_last:f64,
    delta_t:f64,
    label:String,
    ansi:bool
}

fn now()->f64 {
    let dt = std::time::SystemTime::now()
	.duration_since(std::time::UNIX_EPOCH).unwrap();
    (dt.as_secs() as f64) + 1e-9*(dt.subsec_nanos() as f64)
}

impl ProgressIndicator {
    pub fn new(lbl:&str,total:usize)->Self {
	eprintln!("{}",lbl);
        ProgressIndicator {
            total,
            current:0,
            last:0,
            rate:0.0,
            t_first:now(),
            t_prev:0.0,
            t_last:0.0,
            delta_t:0.5,
            label:lbl.to_string(),
	    ansi:true
        }
    }

    pub fn set_ansi(&mut self,ansi:bool) {
	self.ansi = ansi;
    }

    pub fn set_label(&mut self,lbl:&str) {
	self.label = lbl.to_string();
    }

    pub fn set(&mut self,total:usize) {
	self.total = total;
	self.current = 0;
	self.last = 0;
	self.rate = 0.0;
    }

    pub fn update(&mut self,current:usize) {
        self.current = current;
        if current as f64 >= self.last as f64 + self.rate*self.delta_t {
            let t = now();
            if t > self.t_prev + self.delta_t {
                let new_rate = (current - self.last) as f64 / (t - self.t_last);
                self.last = current;
                self.rate = 1.0_f64.max((2.0*self.rate + new_rate)/3.0);
                self.t_last = t;
                self.t_prev = t;
                self.display();
            }
        }
    }

    pub fn display(&self) {
        let elp = self.t_last - self.t_first;
        let eta = (self.total - self.current) as f64 /
	    (self.current as f64/(self.t_last - self.t_first));
	if self.ansi {
	    eprint!("\x1b[A\r\x1b[K");
	}
	eprintln!("{} {:12} {:6.2}% elp {:8.1} ETA {:8.1} est {:8.1}",
		self.label,
		self.current,
		100.0*self.current as f64/self.total as f64,
		elp, eta, elp+eta);
    }
}
