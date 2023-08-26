#![allow(dead_code)]
mod misc_error;
mod footprint;
mod minisvg;

use std::error::Error;
use std::fs::File;
use std::io::{BufWriter,Write};
use std::borrow::Cow;
use log::{error,info,trace};
use url::Url;
use clap::{Arg,App};
use xml::reader::{EventReader,XmlEvent};

use misc_error::MiscError;

struct Config{
    pub base_url:String,
    pub user_name:String,
    pub password:Option<String>,
    pub limit:Option<usize>,
    pub processing_mode:String
}

#[derive(Debug)]
struct TropomiDownloadInfo {
    pub id:String,
    pub filename:String,
    pub format:String,
    pub uuid:String
}

async fn find_tropomi_download_info(cfg:&Config,
				    orbit:u32)->Result<Vec<TropomiDownloadInfo>,Box<dyn Error>> {
    #[derive(Copy,Clone,PartialEq,Eq,Debug)]
    enum State {
	Init,
	Entry,
	Identifier,
	Filename,
	Format,
	UUID,
	TotalResults,
	ItemsPerPage,
    }

    let mut total_results = None;
    let mut start_row = 0;
    let mut n_url = 0;
    let mut res = Vec::new();
    loop {
	info!("Processing from row {} out of {:?}",start_row,total_results);
	if let Some(tr) = total_results {
	    if start_row >= tr {
		trace!("Reached end");
		break;
	    }
	}
	let mut url = Url::parse(&cfg.base_url)?;
	url.path_segments_mut()
	    .map_err(|_| "This URL cannot be a base")?
	    .extend(&["dhus","search"]);
	//let query = format!("{}",id);
	let query = format!("platformname:Sentinel-5 AND producttype:L2__CH4___ AND orbitnumber:{} AND processingmode:{}",orbit,cfg.processing_mode);
	MiscError::convert(url.set_username(&cfg.user_name),"Cannot set user name")?;
	if let Some(pwd) = &cfg.password {
	    MiscError::convert(url.set_password(Some(&pwd)),"Cannot set password")?;
	}
	url.query_pairs_mut().append_pair("q",&query).append_pair("start",&format!("{}",start_row));
	trace!("Querying URL: {}",url);
	let resp = reqwest::get(url)
	    .await?
	    .text()
	    .await?;
	// trace!("RESP: {:?}",resp);
	let mut ev = EventReader::from_str(&resp);
	let mut q = State::Init;
	let mut elems = Vec::new();
	let mut items_per_page = None;

	let mut filename = None;
	let mut identifier = None;
	let mut format = None;
	let mut uuid = None;
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
					filename = None;
					identifier = None;
					format = None;
					uuid = None;
					q = State::Entry;
				    },
				    "str" if q == State::Entry => {
					if let Some(a) = attributes.iter().find(|&a| a.name.local_name == "name") {
					    match a.value.as_str() {
						"filename" => q = State::Filename,
						"identifier" => q = State::Identifier,
						"format" => q = State::Format,
						"uuid" => q = State::UUID,
						_ => ()
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
			    info!("Total results: {}",ntr);
			    q = State::Init;
			},
			(State::ItemsPerPage,XmlEvent::Characters(u)) => {
			    let ipp : usize = u.parse().unwrap();
			    items_per_page = Some(ipp);
			    info!("Items per page: {}",ipp);
			    q = State::Init;
			},
			(State::UUID,XmlEvent::Characters(u)) => {
			    uuid = Some(u);
			    q = State::Entry;
			},
			(State::Identifier,XmlEvent::Characters(u)) => {
			    identifier = Some(u);
			    q = State::Entry;
			},
			(State::Filename,XmlEvent::Characters(u)) => {
			    filename = Some(u);
			    q = State::Entry;
			},
			(State::Format,XmlEvent::Characters(u)) => {
			    format = Some(u);
			    q = State::Entry;
			},
			(State::Entry,XmlEvent::EndElement{ name }) => {
			    if let Some((name2,namespace)) = elems.pop() {
				if name == name2 {
				    if let Some(_pf) = namespace.get("opensearch") {
					match name.local_name.as_str() {
					    "entry" if q == State::Entry => {
						match (&identifier,&format,&filename,&uuid) {
						    (Some(idn),Some(fmt),Some(fnm),Some(uid)) => {
							// if idn == id {
							    let tdi =
								TropomiDownloadInfo{
								    id:idn.clone(),
								    format:fmt.clone(),
								    filename:fnm.clone(),
								    uuid:uid.clone()
								};
							    info!("Found: {:?}",tdi);
							    res.push(tdi);
							// } else {
							//     trace!("Mismatched entry: {}, {}, {}, {}",
							// 	   idn,fmt,fnm,uid);
							// }
						    },
						    _ => {
							trace!("Incomplete entry");
						    }
						}


						q = State::Init;
					    },
					    _ => ()
					}
				    }
				} else {
				    error!("ERROR: Mismatched name {} vs {}",name,name2);
				}
			    } else {
				error!("ERROR: Stack empty");
			    }
			},
			(_,XmlEvent::EndDocument) => break,
			_ => ()
		    }
		},
		Err(e) => {
		    error!("ERR: {}",e);
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
    Ok(res)
}

fn main()->Result<(),Box<dyn Error>> {
    let args = App::new("s5pdownload")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("orbit").multiple(true).help("Orbits to download"))
	.arg(Arg::with_name("verbose").short("v"))
	.arg(Arg::with_name("processing_mode").short("m").long("processing-mode").takes_value(true).default_value("Offline"))
	.get_matches();

    let verbose = args.is_present("verbose");

    simple_logger::SimpleLogger::new()
	.with_level(if verbose { log::LevelFilter::Trace } else { log::LevelFilter::Info })
	.init()?;

    let orbits : Vec<u32> =
	args.values_of("orbit").expect("Specify orbit numbers")
	.map(|o| o.parse::<u32>().unwrap())
	.collect();
    let out_fn = args.value_of("out").expect("Specify output path");
    let processing_mode = args.value_of("processing_mode").unwrap().to_string();

    let runtime = tokio::runtime::Builder::new_multi_thread().enable_all().build()?;

    let cfg = Config{
	base_url:"https://s5phub.copernicus.eu".to_string(),
	user_name:"s5pguest".to_string(),
	password:Some("s5pguest".to_string()),
	limit:Some(5),
    processing_mode
    };

    let out_fd = File::create(out_fn)?;
    let mut out_buf = BufWriter::new(out_fd);
    for orbit in orbits {
	let res = runtime.block_on(find_tropomi_download_info(&cfg,orbit))?;
	for TropomiDownloadInfo{ id,filename,format,uuid } in res.iter() {
	    let f = |x| shell_escape::unix::escape(Cow::from(x));
	    let url = format!("{}/dhus/odata/v1/Products('{}')/$value",cfg.base_url,uuid);
	    write!(out_buf,"ID={}\nFILE={}\nFORMAT={}\nUUID={}\nURL={}\nprocess\n",
		   f(id),
		   f(filename),
		   f(format),
		   f(uuid),
		   f(&url))?;
	}
    }

    Ok(())
}
