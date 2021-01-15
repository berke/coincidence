use nom::{IResult,
	  combinator::eof,
	  sequence::{preceded,delimited,terminated,separated_pair},
	  number::complete::double,
	  multi::separated_list0,
	  character::{streaming::space0,complete::char},
	  bytes::complete::tag};

fn multipolygon3(u:&str)->IResult<&str,(f64,f64)> {
    separated_pair(
	double,
	space0,
	double
    )(u)
}

fn multipolygon2(u:&str)->IResult<&str,Vec<(f64,f64)>> {
    separated_list0(
	delimited(space0,tag(","),space0),
	multipolygon3,
    )(u)
}

fn multipolygon1(u:&str)->IResult<&str,Vec<Vec<(f64,f64)>>> {
    separated_list0(
	delimited(space0,tag(","),space0),
	delimited(char('('),
		  multipolygon2,
		  char(')')))(u)
}

fn multipolygon0(u:&str)->IResult<&str,Vec<Vec<Vec<(f64,f64)>>>> {
    separated_list0(
	delimited(space0,tag(","),space0),
	delimited(char('('),
		  multipolygon1,
		  char(')')))(u)
}

pub fn multipolygon(u:&str)->IResult<&str,Vec<Vec<Vec<(f64,f64)>>>> {
    terminated(
	preceded(
	    tag("MULTIPOLYGON"),
	    preceded(space0,
		     delimited(
			 char('('),
			 multipolygon0,
			 char(')')))),
	eof)(u)
}
