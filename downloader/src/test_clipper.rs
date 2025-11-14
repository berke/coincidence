use geo::{Coord,LineString,Polygon,algorithm::area::Area};
use geo_clipper::Clipper;

fn main() {
    let subject = Polygon::new(
	LineString(vec![
	    Coord { x: 180.0, y: 200.0 },
	    Coord { x: 260.0, y: 200.0 },
	    Coord { x: 260.0, y: 150.0 },
	    Coord { x: 180.0, y: 150.0 },
	]),
	vec![LineString(vec![
	    Coord { x: 215.0, y: 160.0 },
	    Coord { x: 230.0, y: 190.0 },
	    Coord { x: 200.0, y: 190.0 },
	])],
    );

    let clip = Polygon::new(
	LineString(vec![
	    Coord { x: 190.0, y: 210.0 },
	    Coord { x: 240.0, y: 210.0 },
	    Coord { x: 240.0, y: 130.0 },
	    Coord { x: 190.0, y: 130.0 },
	]),
	vec![],
    );

    let result = subject.intersection(&clip, 1.0);
    for poly in result.iter() {
	let a = poly.unsigned_area();
	println!("Intersection area: {}",a);
    }
}
