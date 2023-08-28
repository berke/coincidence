#![allow(dead_code)]

mod misc_error;
mod outline_parser;
mod minisvg;
mod footprint;
mod backoff;

use ron::de::from_reader;
use misc_error::MiscError;
use std::error::Error;
use std::path::PathBuf;
use std::cell::RefCell;
use url::Url;
use xml::reader::{EventReader,XmlEvent};
use chrono::{Datelike,DateTime,Duration,SecondsFormat,Utc,TimeZone};
use footprint::{Footprint,Footprints};

use backoff::{Backoff,BackoffParams};

use self::config::Config;

fn next_month(d:&DateTime<Utc>)->DateTime<Utc> {
    let nd = d.naive_utc().date();
    let mut nd1 = nd;
    while nd1.month() == nd.month() {
	nd1 = nd1.succ_opt().unwrap();
    }
    let d1 = nd1.and_hms_opt(0,0,0).unwrap();
    DateTime::<Utc>::from_utc(d1,Utc)
}

async fn robust_get(ctx:&Context,url:Url)->Result<String,Box<dyn Error>> {
    let mut iattempt = 0;
    loop {
	iattempt += 1;
	match reqwest::get(url.clone()).await {
	    Ok(t) => {
		match t.text().await {
		    Ok(resp) => {
			ctx.backoff.borrow_mut().success();
			return Ok(resp)
		    },
		    Err(e) => {
			println!("Could not get text for URL {} ({}), \
				  trying again... (attempt {})",
				 url,e,iattempt);
		    }
		}
	    },
	    Err(e) => {
		println!("Could not get URL {} ({}), \
			  trying again... (attempt {})",
			 url,e,iattempt);
	    }
	}
	ctx.backoff.borrow_mut().failure().await;
    }
}

struct Context {
    backoff:RefCell<Backoff>
}

impl Context {
    pub fn new()->Self {
	let backoff = RefCell::new(Backoff::new(BackoffParams::default()));
	Self {
	    backoff
	}
    }
}

async fn process_tropomi(ctx:&Context,
			 cfg:&config::Tropomi,year:i32,month:u32)
			 ->Result<Footprints,Box<dyn Error>> {
    #[derive(Copy,Clone,PartialEq,Eq,Debug)]
    enum State { Init,Entry,Footprint,OrbitNumber,Identifier,TotalResults,ItemsPerPage,BeginPosition,EndPosition }

    let mut total_results = None;
    let mut start_row = 0;
    let mut footprints = Vec::new();
    let mut n_url = 0;
    loop {
	println!("Processing from row {} out of {:?}",start_row,total_results);
	if let Some(tr) = total_results {
	    if start_row >= tr {
		println!("Reached end");
		break;
	    }
	}
	let mut url = Url::parse(&cfg.base_url)?;
	let t_start = Utc.with_ymd_and_hms(year,month,1,0,0,0).unwrap();
	let t_end = next_month(&t_start) - Duration::milliseconds(1);
	let query = format!("platformname:{} AND producttype:{} AND processingmode:{} AND beginposition:[{} TO {}]",
			    cfg.platform_name,
			    cfg.product_type,
			    cfg.processing_mode,
			    t_start.to_rfc3339_opts(SecondsFormat::Millis,true),
			    t_end.to_rfc3339_opts(SecondsFormat::Millis,true));
	MiscError::convert(url.set_username(&cfg.user_name),"Cannot set user name")?;
	if let Some(pwd) = &cfg.password {
	    MiscError::convert(url.set_password(Some(&pwd)),"Cannot set password")?;
	}
	url.query_pairs_mut().append_pair("q",&query).append_pair("start",&format!("{}",start_row));
	println!("Querying URL: {}",url);
	let resp = robust_get(ctx,url).await?;
	// println!("RESP: {:?}",resp);
	let mut ev = EventReader::from_str(&resp);
	let mut q = State::Init;
	let mut fp = Footprint::new();
	let mut elems = Vec::new();
	let mut items_per_page = None;
	let mut obs_start = 0.0;
	let mut obs_end = 0.0;
	loop {
	    match ev.next() {
		Ok(e) => {
		    //println!("q={:?} EV {:?}",q,e);
		    match (q,e) {
			(_,XmlEvent::StartElement{ name, attributes, namespace }) => {
			    elems.push((name.clone(),namespace.clone()));
			    if let Some(_pf) = namespace.get("opensearch") {
				//println!("Prefix: {}",pf);
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
				    "date" if q == State::Entry => {
					if let Some(_) = namespace.get("opensearch") {
					    if let Some(a) = attributes.iter().find(|&a| a.name.local_name == "name") {
						match a.value.as_str() {
						    "beginposition" => q = State::BeginPosition,
						    "endposition" => q = State::EndPosition,
						    _ => ()
						}
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
				    },
				    "totalResults" if q == State::Init => {
					q = State::TotalResults;
				    },
				    "itemsPerPage" if q == State::Init => {
					q = State::ItemsPerPage;
				    },
				    _ln => {
					//eprintln!("Unhandled name {}",ln);
				    }
				}
			    } else {
				// println!("NAME {:?}",name);
				// println!("ATTR {:?}",attributes);
				// println!("NAMESPACE {:?}",namespace);
			    }
			},
			(State::TotalResults,XmlEvent::Characters(u)) => {
			    let ntr : usize = u.parse().unwrap();
			    total_results = Some(ntr);
			    println!("Total results: {}",ntr);
			    q = State::Init;
			},
			(State::ItemsPerPage,XmlEvent::Characters(u)) => {
			    let ipp : usize = u.parse().unwrap();
			    items_per_page = Some(ipp);
			    println!("Items per page: {}",ipp);
			    q = State::Init;
			},
			(State::Footprint,XmlEvent::Characters(u)) => {
			    // println!("OUTLINE: {}",u);
			    if let Some(out) = outline_parser::parse_multipolygon(&u) {
				fp.outline = out;
				q = State::Entry;
			    } else {
				eprintln!("ERROR: Cannot parse outline");
			    }
			},
			(State::Identifier,XmlEvent::Characters(u)) => {
			    // println!("ID: {}",u);
			    fp.id = u;
			    q = State::Entry;
			},
			(State::OrbitNumber,XmlEvent::Characters(u)) => {
			    let num : usize = u.parse().unwrap();
			    // println!("ORBNUM: {}",num);
			    fp.orbit = num;
			    q = State::Entry;
			},
			(State::BeginPosition,XmlEvent::Characters(u)) => {
			    obs_start = DateTime::parse_from_rfc3339(&u)?.timestamp() as f64;
			    q = State::Entry;
			},
			(State::EndPosition,XmlEvent::Characters(u)) => {
			    obs_end = DateTime::parse_from_rfc3339(&u)?.timestamp() as f64;
			    q = State::Entry;
			},
			(State::Entry,XmlEvent::EndElement{ name }) => {
			    if let Some((name2,namespace)) = elems.pop() {
				if name == name2 {
				    if let Some(_pf) = namespace.get("opensearch") {
					// println!("Prefix: {}",pf);
					match name.local_name.as_str() {
					    "entry" if q == State::Entry => {
						fp.instrument = "TROPOMI".to_string();
						fp.platform = "Sentinel-5P".to_string();
						fp.time_interval = (obs_start,obs_end);
						footprints.push(fp.clone());
						fp = Footprint::new();
						q = State::Init;
					    },
					    _ => ()
					}
				    }
				} else {
				    eprintln!("ERROR: Mismatched name {} vs {}",name,name2);
				}
			    } else {
				eprintln!("ERROR: Stack empty");
			    }
			},
			(_,XmlEvent::EndDocument) => break,
			_ => ()
		    }
		},
		Err(e) => {
		    eprintln!("ERR: {}",e);
		    break;
		}
	    }
	}
	start_row += items_per_page.unwrap_or(10);
	n_url += 1;
	if let Some(lim) = cfg.limit {
	    if n_url > lim {
		break;
	    }
	}
    }
    Ok(Footprints{ footprints })
}

fn split_once(u:&str,sep:char)->Option<(&str,&str)> {
    let u : Vec<&str> = u.splitn(2,sep).collect();
    if u.len() == 2 {
	Some((u[0],u[1]))
    } else {
	None
    }
}

mod config {
    use serde::Deserialize;
    
    #[derive(Clone,Debug,Deserialize)]
    pub struct Config {
	pub out_path:String,
	pub jobs:Vec<Job>,
	pub draw_footprints:bool,
    }

    #[derive(Clone,Debug,Deserialize)]
    pub struct Job {
	pub year_month_range:((i32,u32),(i32,u32)),
	pub sources:Vec<Source>
    }

    #[derive(Clone,Debug,Deserialize)]
    pub enum Source {
	Tropomi(Tropomi),
	IASI(IASI)
    }

    impl Source {
	pub fn short_name(&self)->&str {
	    match self {
		Self::Tropomi(_) => "tropomi",
		Self::IASI(_) => "iasi"
	    }
	}
    }

    #[derive(Clone,Debug,Deserialize)]
    pub struct Tropomi {
	pub base_url:String,
	pub platform_name:String,
	pub product_type:String,
	pub processing_mode:String,
	pub user_name:String,
	pub password:Option<String>,
	pub limit:Option<usize>
    }

    #[derive(Clone,Debug,Deserialize)]
    pub struct IASI {
	pub base_url:String,
	pub collection:String,
	pub limit:Option<usize>,

	#[serde(default)]
	pub dry_run:bool,

	#[serde(default)]
	pub num_retries:usize,
	pub initial_timeout:f64
    }
}

fn convert_eumetsat_product(id:&str,obj:&json::JsonValue)->Result<Footprint,Box<dyn Error>> {
    let mut outline = Vec::new();

    let geo = &obj["geometry"];
    if let Some(gt) = geo["type"].as_str() {
	match gt {
	    "MultiPolygon" => {
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
	    },
	    "Polygon" => {
		let mut outline = Vec::new();
		let mut polygon = Vec::new();
		for b in geo["coordinates"].members() {
		    let mut ring : Vec<(f64,f64)> = Vec::new();
		    for c in b.members() {
			let x : f64 = MiscError::from_option(c[0].as_f64(),"Cannot get longitude")?;
			let y : f64 = MiscError::from_option(c[1].as_f64(),"Cannot get latitude")?;
			ring.push((x,y));
		    }
		    polygon.push(ring);
		}
		outline.push(polygon);
	    },
	    _ => return MiscError::boxed(&format!("Unsupported geometry type {:?}",gt))
	}
    } else {
	return MiscError::boxed("Geometry type undefined")
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
}

async fn get_iasi_footprints(id:&str,url:&str,timeout:f64)
			     ->Result<Footprint,Box<dyn Error>> {
    println!("Checking footprints for {}",id);
    let resp = 
	reqwest::Client::new()
	.get(url)
	.timeout(std::time::Duration::from_secs_f64(timeout))
	.send()
	.await?
	.text()
	.await?;
    let obj = json::parse(&resp)?;
    match convert_eumetsat_product(id,&obj) {
	Ok(fp) => Ok(fp),
	Err(e) => {
	    eprintln!("Error processing {}: {}, url was {}",id,e,url);
	    Err(e)
	}
    }
}

async fn process_iasi(ctx:&Context,
		      cfg:&config::IASI,year:i32,month:u32)
		      ->Result<Footprints,Box<dyn Error>> {
    // There seems to be an issue with percent-encoding of colons in
    // the collection name
    let mut url = Url::parse(&format!("{}/{}",cfg.base_url,cfg.collection))?;
    url.path_segments_mut()
	.map_err(|_| "This URL cannot be a base")?
	.extend(&["dates",&format!("{:04}",year),&format!("{:02}",month), "products"]);
    url.query_pairs_mut().append_pair("format","json");
    println!("Querying URL: {}",url);

    let mut products : Vec<(String,String)> = Vec::new();
    process_iasi_inner(ctx,url,&mut products).await?;

    println!("Number of products: {}",products.len());

    let mut footprints = Vec::new();

    if !cfg.dry_run {
	let mut n_url = 0;
	for (id,url) in products.iter() {
	    let mut ok = false;
	    let mut timeout = cfg.initial_timeout;
	    for attempt in 0..cfg.num_retries + 1 {
		match get_iasi_footprints(id,url,timeout).await {
		    Ok(fp) => {
			footprints.push(fp);
			ok = true;
			break;
		    },
		    Err(e) => {
			eprintln!("Error processing {}: {}, url was {} (attempt {}/{})",
				  id,e,url,
				  attempt,cfg.num_retries + 1);
			timeout *= 2.0;
		    }
		}
	    }
	    if ok {
		n_url += 1;
		if let Some(lim) = cfg.limit {
		    if n_url > lim {
			break;
		    }
		}
	    } else {
		eprintln!("Was not able to process {}",id);
	    }
	}
    }

    Ok(Footprints{ footprints })
}

async fn process_iasi_inner(ctx:&Context,
			    mut url:Url,
			    products:&mut Vec<(String,String)>)
			    ->Result<(),Box<dyn Error>> {
    loop {
	let resp = robust_get(ctx,url).await?;

	let obj = json::parse(&resp)?;

	for prod in obj["products"].members() {
	    if let Some(id) = prod["id"].as_str() {
		for lk in prod["links"].members() {
		    if let Some(url) = lk["href"].as_str() {
			products.push((id.to_string(),url.to_string()));
		    }
		}
	    }
	}

	if let Some(url_next) = obj["next"]["href"].as_str() {
	    url = Url::parse(url_next)?;
	    println!("Next product at {}",url);
	} else {
	    break;
	}
    }

    Ok(())
}

fn process(ctx:&Context,cfg:&Config)->Result<(),Box<dyn Error>> {
    use config::{Job,Source};
    
    let runtime = tokio::runtime::Builder::new_multi_thread().enable_all().build()?;

    for job in cfg.jobs.iter() {
	let &Job{ year_month_range:((y0,m0),(y1,m1)),ref sources } = job;

	let mut y = y0;
	let mut m = m0;
	loop {
	    if y > y1 || (y == y1 && m > m1) {
		break;
	    }
	    println!("Processing {:04}-{:02}...",y,m);
	    let mut path = PathBuf::from(&cfg.out_path);
	    path.push(&format!("{:04}-{:02}",y,m));
	    std::fs::create_dir_all(&path)?;

	    let mut k = 0;
	    for s in sources.iter() {
		let sname = s.short_name();
		let mut bin_path = path.clone();
		bin_path.push(&format!("{}-{:03}.mpk",sname,k));

		if bin_path.exists() {
		    println!("Path {:?} already downloaded",bin_path);
		} else {
		    let fps =
			match s {
			    Source::Tropomi(trop) =>
				runtime.block_on(
				    process_tropomi(ctx,trop,y,m))?,
			    Source::IASI(iasi) =>
				runtime.block_on(
				    process_iasi(ctx,iasi,y,m))?
			};

		    let mut tmp_bin_path = path.clone();
		    tmp_bin_path.push(&format!("{}-{:03}.mpk",sname,k));

		    fps.save_to_file(&tmp_bin_path)?;
		    std::fs::rename(tmp_bin_path,bin_path)?;

		    if cfg.draw_footprints {
			let mut svg_path = path.clone();
			svg_path.push(&format!("{}-{:03}.svg",sname,k));
			fps.draw(&svg_path)?;
		    }
		}

		k += 1;
	    }

	    m += 1;
	    if m == 13 {
		m = 1;
		y += 1;
	    }
	}
    }
    Ok(())
}

fn main()->Result<(),Box<dyn Error>> {
    let cfg_fn = MiscError::from_option(std::env::args().nth(1),"Specify path to configuration file")?;
    let fd = std::fs::File::open(cfg_fn)?;
    let cfg : Config = from_reader(fd)?;
    let ctx = Context::new();
    process(&ctx,&cfg)
}
