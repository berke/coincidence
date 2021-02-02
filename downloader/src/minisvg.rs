#![allow(dead_code)]
use std::path::Path;
use std::fs::File;
use std::io::{Write,BufWriter};
use std::error::Error;

pub struct MiniSVG {
    buf:BufWriter<File>,
    stroke:Option<(u32,f64,f64)>,
    fill:Option<(u32,f64)>,
    x0:f64,
    y0:f64
}

impl Drop for MiniSVG {
    fn drop(&mut self) {
	write!(self.buf,"</svg>").expect("Cannot finish SVG file");
    }
}

impl MiniSVG {
    pub fn new<P:AsRef<Path>>(path:P,width:f64,height:f64,x0:f64,y0:f64)->Result<Self,Box<dyn Error>> {
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
	       viewBox=\"{} {} {} {}\"
	       version=\"1.1\">\n",
	       width,
	       height,
	       0.0,
	       0.0,
	       width,
	       height)?;
	write!(buf,"<rect style=\"fill:#ffffff;fill-rule:evenodd\" width=\"{}\" height=\"{}\" x=\"{}\" y=\"{}\" />\n",
	       width,
	       height,
	       0.0,
	       0.0)?;
	Ok(Self{ buf,stroke:None,fill:None,x0,y0 })
    }

    fn write_style(&mut self)->Result<(),Box<dyn Error>> {
	write!(self.buf,"style=\"")?;
	match self.fill {
	    None => write!(self.buf,"fill:none;")?,
	    Some((c,op)) => write!(self.buf,"fill:#{:06x};fill-rule:evenodd;opacity:{};",c,op)?
	}
	match self.stroke {
	    None => write!(self.buf,"stroke:none")?,
	    Some((c,w,op)) => write!(self.buf,"stroke-width:{}mm;stroke:#{:06x};stroke-opacity:{}",w,c,op)?
	}
	write!(self.buf,"\"")?;
	Ok(())
    }

    pub fn simple_polygon(&mut self,path:&Vec<(f64,f64)>)->Result<(),Box<dyn Error>> {
	write!(self.buf,"<path ")?;
	self.write_style()?;
	write!(self.buf," d=\"M")?;
	for (x,y) in path.iter() {
	    write!(self.buf," {},{}",x - self.x0,y - self.y0)?;
	}
	write!(self.buf," Z\"/>\n")?;
	Ok(())
    }

    pub fn multi_polygon(&mut self,polys:&Vec<Vec<Vec<(f64,f64)>>>)->Result<(),Box<dyn Error>> {
	for p in polys.iter() {
	    self.polygon(p)?;
	}
	Ok(())
    }

    pub fn polygon(&mut self,polys:&Vec<Vec<(f64,f64)>>)->Result<(),Box<dyn Error>> {
	write!(self.buf,"<path ")?;
	self.write_style()?;
	write!(self.buf," d=\"")?;
	let mut first = true;
	for poly in polys.iter() {
	    if first {
		first = false;
	    } else {
		write!(self.buf," ")?;
	    }
	    write!(self.buf,"M")?;
	    for (x,y) in poly.iter() {
		write!(self.buf," {},{}",x - self.x0,y - self.y0)?;
	    }
	    write!(self.buf," Z")?;
	}
	write!(self.buf,"\"/>\n")?;
	Ok(())
    }

    pub fn circle(&mut self,x0:f64,y0:f64,r:f64)->Result<(),Box<dyn Error>> {
	write!(self.buf,"<circle ")?;
	self.write_style()?;
	write!(self.buf," cx=\"{}\" cy=\"{}\" r=\"{}\"/>\n",x0 - self.x0,y0 - self.y0,r)?;
	Ok(())
    }

    pub fn text(&mut self,x:f64,y:f64,s:f64,text:&str)->Result<(),Box<dyn Error>> {
	if let Some((c,op)) = self.fill {
	    write!(self.buf,"<text xml:space=\"preserve\" x=\"{}\" y=\"{}\" style=\"font-family:osifont;font-style:normal;font-weight:normal;font-size:{}mm;fill:#{:06x};fill-opacity:{};stroke:none\">{}</text>",
		   x - self.x0,
		   y - self.y0,
		   s,c,op,
		   &xml::escape::escape_str_pcdata(text))?;
	}
	Ok(())
    }

    pub fn set_stroke(&mut self,stroke:Option<(u32,f64,f64)>) {
	self.stroke = stroke;
    }

    pub fn set_fill(&mut self,fill:Option<(u32,f64)>) {
	self.fill = fill;
    }
}
