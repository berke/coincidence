use geo::{Coordinate, LineString, Polygon};
use geo_clipper::Clipper;

fn main() {
    let subject = Polygon::new(
	LineString(vec![
	    Coordinate { x: 180.0, y: 200.0 },
	    Coordinate { x: 260.0, y: 200.0 },
	    Coordinate { x: 260.0, y: 150.0 },
	    Coordinate { x: 180.0, y: 150.0 },
	]),
	vec![LineString(vec![
	    Coordinate { x: 215.0, y: 160.0 },
	    Coordinate { x: 230.0, y: 190.0 },
	    Coordinate { x: 200.0, y: 190.0 },
	])],
    );

    let clip = Polygon::new(
	LineString(vec![
	    Coordinate { x: 190.0, y: 210.0 },
	    Coordinate { x: 240.0, y: 210.0 },
	    Coordinate { x: 240.0, y: 130.0 },
	    Coordinate { x: 190.0, y: 130.0 },
	]),
	vec![],
    );

    let result = subject.intersection(&clip, 1.0);
}
