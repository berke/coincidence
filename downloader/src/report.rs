use super::*;

pub struct Report {
    buf:BufWriter<File>
}

pub struct ReportLine<'a> {
    /// Intersection ID
    pub n_inter:usize,

    /// Timestamp
    pub ts:DateTime<Utc>,
    pub min_delta_t:f64,
    pub tau:f64,
    pub psi:f64,

    pub id1:&'a str,
    pub lon1:f64,
    pub lat1:f64,

    pub id2:&'a str,
    pub lon2:f64,
    pub lat2:f64
}

impl Report {
    pub fn new<P:AsRef<Path>>(path:P)->Result<Self> {
	let fd = File::create(path)?;
	let buf = BufWriter::new(fd);
	Ok(Self { buf })
    }

    pub fn show_header(&mut self)->Result<()> {
	writeln!(self.buf,
		 "# n_inter ts min_delta_t tau psi id1 lon1 lat1 id2 lon2 lat2")?;
	Ok(())
    }

    pub fn add_line(&mut self,line:&ReportLine)->Result<()> {
	let &ReportLine {
	    n_inter,
	    ts,
	    min_delta_t,
	    tau,
	    psi,
	    ref id1,
	    lon1,
	    lat1,
	    ref id2,
	    lon2,
	    lat2
	} = line;

	write!(self.buf,
	       "{:04}\t\
		{}\t\
		{}\t\
		{:5.1}\t\
		{:5.3}\t",
	       n_inter,
	       ts,
	       min_delta_t,
	       tau,
	       psi)?;
	write!(self.buf,
	       "{}\t{}\t",
	       id1,
	       id2)?;
	write!(self.buf,
	       "{:5.3}\t{:5.3}\t{:5.3}\t{:5.3}",
	       lon1,
	       lat1,
	       lon2,
	       lat2)?;
	writeln!(self.buf)?;

	Ok(())
    }
}
