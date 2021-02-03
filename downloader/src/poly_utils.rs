#![allow(dead_code)]

use geo::{MultiPolygon,Polygon,LineString};
use geo::algorithm::intersects::Intersects;
use geo_clipper::Clipper;

pub const FACTOR : f64 = (1 << 24) as f64 / 360.0;

pub fn polygon_to_vec<F:Fn((f64,f64))->(f64,f64)>(p:&Polygon<f64>,f:F)->Vec<Vec<(f64,f64)>> {
    let (pve1,pvi1) = p.clone().into_inner();
    let pve1 : Vec<(f64,f64)> = pve1.points_iter().map(|pt| f((pt.x(),pt.y()))).collect();
    let mut pvi1 : Vec<Vec<(f64,f64)>> =
	pvi1.iter().map(|ls| ls.points_iter().map(|pt| f((pt.x(),pt.y()))).collect()).collect();
    let mut u = Vec::new();
    u.push(pve1);
    u.append(&mut pvi1);
    u
}

pub fn multipolygon_to_vec(mp:&MultiPolygon<f64>)->Vec<Vec<Vec<(f64,f64)>>> {
    mp.iter().map(|p| polygon_to_vec(p,|q| q)).collect()
}

pub fn clip_to_roi(roi:&Polygon<f64>,mp:&MultiPolygon<f64>)->MultiPolygon<f64> {
    let mut res = Vec::new();
    for p in mp.iter() {
	if roi.intersects(p) {
	    let inter = roi.intersection(p,FACTOR);
	    let mut inter : Vec<Polygon<f64>> = inter.iter().map(|x| x.clone()).collect();
	    res.append(&mut inter);
	}
    }
    let mp_out : MultiPolygon<f64> = res.into();
    mp_out
}

pub fn rectangle((lon0,lat0):(f64,f64),(lon1,lat1):(f64,f64))->Polygon<f64> {
    Polygon::new(
	LineString::from(vec![
	    (lon0,lat0),
	    (lon1,lat0),
	    (lon1,lat1),
	    (lon0,lat1)
	]),
	vec![])
}
