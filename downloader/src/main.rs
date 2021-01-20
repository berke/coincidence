mod misc_error;
mod outline_parser;
mod minisvg;
mod footprint;

use misc_error::MiscError;
use std::error::Error;
use url::Url;
use xml::reader::{EventReader,XmlEvent};
use minisvg::MiniSVG;
use footprint::Footprint;

async fn main_s5p()->Result<(),Box<dyn Error>> {
    let mut url = Url::parse("https://s5phub.copernicus.eu/dhus/search")?;
    let query = "platformname:Sentinel-5 AND producttype:L1B_RA_BD7 AND processinglevel:L1B AND processingmode:Offline AND beginPosition:[2019-05-18T00:00:00.000Z TO 2019-05-19T23:59:59.999Z]";
    //orbitnumber:15839";
    MiscError::convert(url.set_username("s5pguest"),"Cannot set user name")?;
    MiscError::convert(url.set_password(Some("s5pguest")),"Cannot set password")?;
    url.query_pairs_mut().append_pair("q",&query);
    let resp = reqwest::get(url)
	.await?
	.text()
	.await?;
    println!("RESP: {:?}",resp);
    let mut ev = EventReader::from_str(&resp);
    #[derive(Copy,Clone,PartialEq,Eq,Debug)]
    enum State { Init,Entry,Footprint,OrbitNumber,Identifier }
    let mut q = State::Init;
    let mut footprints = Vec::new();
    let mut fp = Footprint::new();
    let mut elems = Vec::new();
    loop {
	match ev.next() {
	    Ok(e) => {
		println!("q={:?} EV {:?}",q,e);
		match (q,e) {
		    (_,XmlEvent::StartElement{ name, attributes, namespace }) => {
			elems.push((name.clone(),namespace.clone()));
			if let Some(pf) = namespace.get("opensearch") {
			    println!("Prefix: {}",pf);
			    match name.local_name.as_str() {
				"entry" if q == State::Init => {
				    q = State::Entry
				},
				"str" if q == State::Entry => {
				    if let Some(a) = attributes.iter().find(|&a| a.name.local_name == "name") {
					match a.value.as_str() {
					    "footprint" => q = State::Footprint,
					    "identifier" => q = State::Identifier,
					    _ => ()
					}
				    }
				},
				"int" if q == State::Entry => {
				    if let Some(_) = namespace.get("opensearch") {
					if let Some(a) = attributes.iter().find(|&a| a.name.local_name == "name") {
					    match a.value.as_str() {
						"orbitnumber" => q = State::OrbitNumber,
						_ => ()
					    }
					}
				    }
				}
				ln => {
				    println!("Unhandled name {}",ln);
				}
			    }
			} else {
			    println!("NAME {:?}",name);
			    println!("ATTR {:?}",attributes);
			    println!("NAMESPACE {:?}",namespace);
			}
		    },
		    (State::Footprint,XmlEvent::Characters(u)) => {
			println!("OUTLINE: {}",u);
			if let Some(out) = outline_parser::parse_multipolygon(&u) {
			    fp.set_outline(&out);
			    q = State::Entry;
			} else {
			    println!("ERROR: Cannot parse outline");
			}
		    },
		    (State::Identifier,XmlEvent::Characters(u)) => {
			println!("ID: {}",u);
			fp.set_id(&u);
			q = State::Entry;
		    },
		    (State::OrbitNumber,XmlEvent::Characters(u)) => {
			let num : usize = u.parse().unwrap();
			println!("ORBNUM: {}",num);
			fp.set_orbit(num);
			q = State::Entry;
		    },
		    (State::Entry,XmlEvent::EndElement{ name }) => {
			if let Some((name2,namespace)) = elems.pop() {
			    if name == name2 {
				if let Some(pf) = namespace.get("opensearch") {
				    println!("Prefix: {}",pf);
				    match name.local_name.as_str() {
					"entry" if q == State::Entry => {
					    footprints.push(fp.clone());
					    fp.clear();
					    q = State::Init;
					},
					_ => ()
				    }
				}
			    } else {
				println!("ERROR: Mismatched name {} vs {}",name,name2);
			    }
			} else {
			    println!("ERROR: Stack empty");
			}
		    },
		    (_,XmlEvent::EndDocument) => break,
		    _ => ()
		}
	    },
	    Err(e) => {
		println!("ERR: {}",e);
		break;
	    }
	}
    }
    let n_footprint = footprints.len();
    println!("Number of footprints found: {}",n_footprint);
    let mut ms = MiniSVG::new("out.svg",360.0,180.0)?;
    ms.set_stroke(Some((0xff0000,0.25)));
    ms.set_fill(Some(0xffff80));
    for f in footprints.iter() {
	println!("Orbit: {}",f.orbit);
	println!("ID: {}",f.id);
	for a in f.outline.iter() {
	    for b in a.iter() {
		let mp : Vec<(f64,f64)> = b.iter().map(|(x,y)| (x+180.0,y+90.0)).collect();
		ms.polygon(&mp)?;
		// println!("POLYGON {}",b.len());
		// for (x,y) in b.iter() {
		//     println!("{},{}",x,y);
		// }
	    }
	}
    }
    Ok(())
}

//#[tokio::main]

fn main()->Result<(),Box<dyn Error>> {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap()
        .block_on(main_s5p())
}
