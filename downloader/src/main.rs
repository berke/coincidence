mod misc_error;

use misc_error::MiscError;
use std::error::Error;
use url::Url;
use xml::reader::{EventReader,XmlEvent};

#[tokio::main]
async fn main()->Result<(),Box<dyn Error>> {
    let mut url = Url::parse("https://s5phub.copernicus.eu/dhus/search")?;
    let query = "platformname:Sentinel-5 AND (producttype:L1B_RA_BD7 OR producttype:L1B_RA_BD8) AND processinglevel:L1B AND processingmode:Offline AND orbitnumber:15839";
    MiscError::convert(url.set_username("s5pguest"),"Cannot set user name")?;
    MiscError::convert(url.set_password(Some("s5pguest")),"Cannot set password")?;
    url.query_pairs_mut().append_pair("q",&query);
    let resp = reqwest::get(url)
	.await?
	.text()
	.await?;
    println!("RESP: {:?}",resp);
    let mut ev = EventReader::from_str(&resp);
    #[derive(Copy,Clone)]
    enum State { Init,Footprint,Done }
    let mut q = State::Init;
    let mut footprints = Vec::new();
    loop {
	match ev.next() {
	    Ok(e) => {
		println!("EV {:?}",e);
		match (q,e) {
		    (State::Init,XmlEvent::StartElement{ name, attributes, namespace }) => { // if name == "gmlfootprint" => {
			if name.local_name == "str" {
			    if let Some(pf) = namespace.get("opensearch") {
				// println!("OSEARCH PF {}",pf);
				if let Some(a) = attributes.iter().find(|&a| a.name.local_name == "name") {
				    if a.value == "gmlfootprint" {
					q = State::Footprint;
				    }
				    // println!("name={}",a.value);
				    // 		       // 	       println!("LOCNAME {} VAL {}",
				    // 		       // 			a.name.local_name, a.value);
				    // 		       // 	   }
				    // 		       // 	   false
				    // 		       // });
				}
			    }
			}
			// println!("NAME {:?}",name);
			// println!("ATTR {:?}",attributes);
			// println!("NAMESPACE {:?}",namespace);
		    },
		    (State::Footprint,XmlEvent::Characters(u)) => {
			// println!("GML: {}",u);
			footprints.push(u);
			q = State::Init;
		    }
		    (_,XmlEvent::EndElement{ name, .. }) => {
			// println!("END {}",name);
		    },
		    (_,XmlEvent::EndDocument) => break,
		    (_,x) => {
			// println!("OTHER {:?}",x);
		    },
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
    for f in footprints.iter() {
	println!(">>> {}",f);
    }
    Ok(())
}
