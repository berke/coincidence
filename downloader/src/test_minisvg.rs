mod minisvg;

use std::error::Error;
use minisvg::MiniSVG;

pub fn main()->Result<(),Box<dyn Error>> {
    let mut ms = MiniSVG::new("out.svg",360.0,180.0,0.0,0.0)?;
    ms.set_stroke(Some((0xff0000,1.0,1.0)));
    ms.simple_polygon(&vec![(10.0,20.0),
			    (30.0,20.0),
			    (30.0,50.0),
			    (10.0,50.0)])?;
    Ok(())
}
