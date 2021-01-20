mod misc_error;
mod outline_parser;
mod minisvg;
mod footprint;

use misc_error::MiscError;
use std::error::Error;
use url::Url;
use xml::reader::{EventReader,XmlEvent};
use chrono::DateTime;
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
    let mut fp;
    let mut elems = Vec::new();
    loop {
	fp = Footprint::new();
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


fn split_once(u:&str,sep:char)->Option<(&str,&str)> {
    let u : Vec<&str> = u.splitn(2,sep).collect();
    if u.len() == 2 {
	Some((u[0],u[1]))
    } else {
	None
    }
}

fn convert_eumetsat_product(id:&str,obj:&json::JsonValue)->Result<Footprint,Box<dyn Error>> {
    let geo = &obj["geometry"];
    if let Some("MultiPolygon") = geo["type"].as_str() {
	let mut outline = Vec::new();
	for a in geo["coordinates"].members() {
	    let mut polygon = Vec::new();
	    for b in a.members() {
		let mut ring : Vec<(f64,f64)> = Vec::new();
		for c in b.members() {
		    let x : f64 = MiscError::from_option(c[0].as_f64(),"Cannot get longitude")?;
		    let y : f64 = MiscError::from_option(c[1].as_f64(),"Cannot get latitude")?;
		    ring.push((x,y));
		}
		polygon.push(ring);
	    }
	    outline.push(polygon);
	}
	let props = &obj["properties"];
	if let Some(date) = props["date"].as_str() {
	    if let Some((obs_start,obs_end)) = split_once(date,'/') {
	    	let obs_start = DateTime::parse_from_rfc3339(obs_start)?.timestamp() as f64;
	    	let obs_end = DateTime::parse_from_rfc3339(obs_end)?.timestamp() as f64;
		let acqi = &props["acquisitionInformation"][0];
    		if let Some(platform) = acqi["platform"]["platformShortName"].as_str() {
		    if let Some(instrument) = acqi["instrument"]["instrumentShortName"].as_str() {
			Ok(Footprint {
			    orbit:0,
			    id:id.to_string(),
			    platform:platform.to_string(),
			    instrument:instrument.to_string(),
			    time_interval:(obs_start,obs_end),
			    outline
			})
		    } else {
			MiscError::boxed("Cannot determine instrument")
		    }
		} else {
		    MiscError::boxed("Cannot determine platform")
		}
	    } else {
		MiscError::boxed("Cannot split date")
	    }
	} else {
	    MiscError::boxed("Invalid date")
	}
    } else {
	MiscError::boxed("Geometry type undefined or not MultiPolygon")
    }
    // } else {
    // 		} else {
    // 		    println!("No platform for {}",id);
    // 		}
    // 	    } else {
    // 		println!("Cannot split date for {}",id);
    // 	    }
    // 	} else {
    // 	    println!("No date for {}",id);
    // 	}
    // }
}

async fn main_metop()->Result<(),Box<dyn Error>> {
    let cat = "EO%3AEUM%3ADAT%3AMETOP%3AIASIL1C-ALL";
    let mut url = Url::parse(&format!("https://api.eumetsat.int/data/browse/collections/{}",cat))?;
    let year : u32 = 2019;
    let month : u32 = 06;
    url.path_segments_mut()
	.map_err(|_| "This URL cannot be a base")?
	.extend(&["dates",&format!("{:04}",year),&format!("{:02}",month), "products"]);
    url.query_pairs_mut().append_pair("format","json");
    println!("Requesting URL {}",url.as_str());
    let resp = reqwest::get(url)
    	.await?
    	.text()
    	.await?;
    println!("RESP: {:?}",resp);
    let obj = json::parse(&resp)?;
    let mut products : Vec<(String,String)> = Vec::new();
    for prod in obj["products"].members() {
	if let Some(id) = prod["id"].as_str() {
	    println!("{}",id);
	    for lk in prod["links"].members() {
		if let Some(url) = lk["href"].as_str() {
		    products.push((id.to_string(),url.to_string()));
		}
	    }
	}
    }

    let max_product = 1;
    let mut n_product = 0;
    let mut footprints = Vec::new();
    for (id,url) in products.iter() {
	let resp = reqwest::get(url)
	    .await?
	    .text()
	    .await?;
	let obj = json::parse(&resp)?;
	// let geo = &obj["geometry"];
	let fp = convert_eumetsat_product(id,&obj)?;
	footprints.push(fp);
	// // if let Some("MultiPolygon") = geo["type"].as_str() {
	// // } else {
	// //     println!(""
	// // }
	// let props = &obj["properties"];
	// if let Some(date) = props["date"].as_str() {
	//     if let Some((obs_start,obs_end)) = split_once(date,'/') {
	// 	let obs_start = DateTime::parse_from_rfc3339(obs_start)?.timestamp() as f64;
	// 	let obs_end = DateTime::parse_from_rfc3339(obs_end)?.timestamp() as f64;
	// 	if let Some(platform) = props["acquisitionInformation"][0]["platform"]["platformShortName"].as_str()
	// 	{
	// 	    println!("{} {} {} {} {}",
	// 		     id,
	// 		     platform,
	// 		     obs_start,
	// 		     obs_end,
	// 		     url);
	// 	} else {
	// 	    println!("No platform for {}",id);
	// 	}
	//     } else {
	// 	println!("Cannot split date for {}",id);
	//     }
	// } else {
	//     println!("No date for {}",id);
	// }
	n_product += 1;
	if n_product >= max_product {
	    break;
	}
    }
    println!("FOOTPRINTS:\n{:?}",footprints);
    Ok(())
}

fn main()->Result<(),Box<dyn Error>> {
    let instr = std::env::args().nth(1).expect("Specify instrument: tropomi or iasi");
    match instr.as_str() {
	"tropomi" =>
	    tokio::runtime::Builder::new_multi_thread()
	    .enable_all()
	    .build()
	    .unwrap()
	    .block_on(main_s5p()),
	"iasi" =>
	    tokio::runtime::Builder::new_multi_thread()
	    .enable_all()
	    .build()
	    .unwrap()
	    .block_on(main_metop()),
	_ => Err(Box::new(MiscError::new(&format!("Invalid instrument {}",instr))))
    }
}
