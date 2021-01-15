use std::path::{Path,PathBuf};
use std::fs::File;
use std::io::{Read,Write,BufWriter};
use std::error::Error;

pub struct MiniSVG {
    buf:BufWriter<File>,
    stroke:Option<(u32,f64)>,
    fill:Option<u32>
}

impl Drop for MiniSVG {
    fn drop(&mut self) {
	write!(self.buf,"</svg>").expect("Cannot finish SVG file");
    }
}

impl MiniSVG {
    pub fn new<P:AsRef<Path>>(path:P,width:f64,height:f64)->Result<Self,Box<dyn Error>> {
	let fd = File::create(path)?;
	let mut buf = BufWriter::new(fd);

	write!(buf,"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<svg xmlns:dc=\"http://purl.org/dc/elements/1.1/\"
	       xmlns:cc=\"http://creativecommons.org/ns#\"
	       xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"
	       xmlns:svg=\"http://www.w3.org/2000/svg\"
	       xmlns=\"http://www.w3.org/2000/svg\"
	       width=\"{}mm\"
	       height=\"{}mm\"
	       viewBox=\"0 0 {} {}\"
	       version=\"1.1\">\n",
	       width,
	       height,
	       width,
	       height)?;
	write!(buf,"<rect style=\"fill:#ffffff;fill-rule:evenodd\" width=\"{}\" height=\"{}\" x=\"0\" y=\"0\" />\n",
	       width,
	       height)?;
	Ok(Self{ buf,stroke:None,fill:None })
    }

    fn write_style(&mut self)->Result<(),Box<dyn Error>> {
	write!(self.buf,"style=\"")?;
	match self.fill {
	    None => write!(self.buf,"fill:none;")?,
	    Some(c) => write!(self.buf,"fill:#{:06x};fill-rule:evenodd;",c)?
	}
	match self.stroke {
	    None => write!(self.buf,"stroke:none")?,
	    Some((c,w)) => write!(self.buf,"stroke-width:{};stroke:#{:06x}",w,c)?
	}
	write!(self.buf,"\"")?;
	Ok(())
    }

    pub fn polygon(&mut self,path:&Vec<(f64,f64)>)->Result<(),Box<dyn Error>> {
	write!(self.buf,"<path ")?;
	self.write_style()?;
	write!(self.buf," d=\"M")?;
	for (x,y) in path.iter() {
	    write!(self.buf," {},{}",x,y)?;
	}
	write!(self.buf," Z\"/>\n")?;
	Ok(())
    }

    pub fn set_stroke(&mut self,stroke:Option<(u32,f64)>) {
	self.stroke = stroke;
    }

    pub fn set_fill(&mut self,fill:Option<u32>) {
	self.fill = fill;
    }
}
