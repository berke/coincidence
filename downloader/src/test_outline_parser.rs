#![allow(dead_code)]

mod outline_parser;

pub fn main() {
    let u = std::env::args().nth(1).expect("No string to parse");
    println!("INPUT: {:?}",u);
    match outline_parser::multipolygon(&u) {
	Ok((rest,middle)) => {
	    println!("OUT: {:?}",middle);
	    println!("REST: {:?}",rest);
	},
	Err(e) => {
	    panic!("ERROR: {:?}",e);
	}
    }
}
