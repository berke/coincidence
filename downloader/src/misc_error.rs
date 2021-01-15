use std::fmt;
use std::error::Error;

#[derive(Debug)]
pub struct MiscError {
    text:String
}

impl MiscError {
    pub fn new(text:&str)->Self {
	Self{ text:text.to_string() }
    }

    pub fn convert<T,U>(r:Result<T,U>,text:&str)->Result<T,Box<dyn Error>> {
	match r {
	    Ok(x) => Ok(x),
	    Err(_) => Err(Box::new(Self::new(text)))
	}
    }
}

impl fmt::Display for MiscError {
    fn fmt(&self,f:&mut fmt::Formatter<'_>)->fmt::Result {
	write!(f,"{}",self.text)
    }
}

impl Error for MiscError {
}
