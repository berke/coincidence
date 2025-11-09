use super::*;

pub struct Report {
    buf:BufWriter<File>
}

pub struct ReportLine<'a> {
    pub n_inter:usize,
    pub ts0:DateTime<Utc>,
    pub ts1:DateTime<Utc>,
    pub min_delta_t:f64,
    pub tau:f64,
    pub psi:f64,
    pub id1:&'a str,
    pub id2:&'a str,
    pub c_x:f64,
    pub c_y:f64
}

impl Report {
    pub fn new<P:AsRef<Path>>(path:P)->Result<Self,Box<dyn Error>> {
	let fd = File::create(path)?;
	let buf = BufWriter::new(fd);
	Ok(Self { buf })
    }

    pub fn add_line(&mut self,line:&ReportLine)->Result<(),Box<dyn Error>> {
	let &ReportLine {
	    n_inter,
	    ts0,
	    ts1,
	    min_delta_t,
	    tau,
	    psi,
	    ref id1,
	    ref id2,
	    c_x,
	    c_y,
	} = line;
	writeln!(self.buf,
		 "{:04}\t{}\t{}\t{:5.1}\t{:5.3}\t{:5.3}\t{}\t{}\t{:5.3}\t{:5.3}",
		 n_inter,
		 ts0,
		 ts1,
		 min_delta_t,
		 tau,
		 psi,
		 id1,
		 id2,
		 c_x,
		 c_y)?;
	Ok(())
    }
}
