#![allow(dead_code)]
mod misc_error;
mod footprint;
mod minisvg;
mod amcut;
mod poly_utils;

use std::error::Error;
use std::ffi::OsString;
use std::path::PathBuf;

use log::{error,info};
use clap::{Arg,App};
use misc_error::MiscError;
use footprint::{Footprint,FootprintLike,Footprints};
use ndarray::{s,Array1,Array2};
use std::collections::{BTreeMap,BTreeSet};
use serde_json::{Map,to_value};

struct FancyFootprint {
    fp:Footprint,
    xch4:f64,
    sigma_xch4:f64,
    xch4_prior:f64,
    sigma_xch4_prior:f64,
    xch4_tropomi:f64,
    sigma_xch4_tropomi:f64,
    t_unix:f64,
    t_unix_tropomi:f64,
    lat:f64,
    lon:f64,
    lat_tropomi:f64,
    lon_tropomi:f64,
    converged:bool,
    chi2:f64
}

impl FootprintLike for FancyFootprint {
    fn orbit(&self)->usize { self.fp.orbit() }
    fn id(&self)->&str { self.fp.id() }
    fn platform(&self)->&str { self.fp.platform() }
    fn instrument(&self)->&str { self.fp.instrument() }
    fn time_interval(&self)->(f64,f64) { self.fp.time_interval() }
    fn outline(&self)->&Vec<Vec<Vec<(f64,f64)>>> { self.fp.outline() }
    fn properties(&self)->Map<String,serde_json::Value> {
	let mut map = Map::new();
	map.insert(String::from("xch4"),to_value(self.xch4).unwrap());
	map.insert(String::from("sigma_xch4"),to_value(self.sigma_xch4).unwrap());
	map.insert(String::from("xch4_prior"),to_value(self.xch4_prior).unwrap());
	map.insert(String::from("sigma_xch4_prior"),to_value(self.sigma_xch4_prior).unwrap());
	map.insert(String::from("xch4_tropomi"),to_value(self.xch4_tropomi).unwrap());
	map.insert(String::from("sigma_xch4_tropomi"),to_value(self.sigma_xch4_tropomi).unwrap());
	map.insert(String::from("t_unix"),to_value(self.t_unix).unwrap());
	map.insert(String::from("t_unix_tropomi"),to_value(self.t_unix_tropomi).unwrap());
	map.insert(String::from("lat"),to_value(self.lat).unwrap());
	map.insert(String::from("lon"),to_value(self.lon).unwrap());
	map.insert(String::from("lat_tropomi"),to_value(self.lat_tropomi).unwrap());
	map.insert(String::from("lon_tropomi"),to_value(self.lon_tropomi).unwrap());
	map.insert(String::from("converged"),to_value(self.converged).unwrap());
	map.insert(String::from("chi2"),to_value(self.chi2).unwrap());
	map
    }
}

fn main()->Result<(),Box<dyn Error>> {
    simple_logger::SimpleLogger::new().init()?;
    let _ = hdf5::silence_errors();

    let args = App::new("mkretmap")
	.arg(Arg::with_name("out").short("o").long("output").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("input").short("i").long("input").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("iasifpdir").long("iasifpdir").value_name("PATH").takes_value(true).required(true))
	.arg(Arg::with_name("limit").long("limit").value_name("N").takes_value(true).required(false))
	.get_matches();

    let out_base = args.value_of("out").expect("Specify output base");
    let input_dir = args.value_of("input").expect("Specify input directory");
    let iasi_fp_dir = args.value_of("iasifpdir").expect("Specify IASI footprint directory");
    let limit = args.value_of("limit").map(|x| x.parse::<usize>().expect("Invalid count"));
    
    let iasi_ret_re = regex::Regex::new(r"^(IASI_xxx_.*)-(\d+)-(\d+)-(\d+)-ret.h5$")?;

    struct Retrieval {
	path:OsString,
	prefix:String,
	base:String,
	igra:usize,
	iscan:usize,
	ipix:usize
    }

    // Get retrievals
    let mut retrievals = Vec::new();

    let mut ids : BTreeSet<String> = BTreeSet::new();

    let mut count = 0;
    for dent in std::fs::read_dir(input_dir)?.flatten() {
	if let Some(l) = limit {
	    if count > l {
		break;
	    }
	}
	if dent.file_type()?.is_file() {
	    let path = dent.path();
	    if let Some(name) = path.file_name() {
		if let Some(u) = name.to_str() {
		    if let Some(cap) = iasi_ret_re.captures(u) {
			let base = MiscError::from_option(cap.get(1),"Bad base name")?.as_str();
			let igra_str = MiscError::from_option(cap.get(2),"Bad granule")?.as_str();
			let igra = igra_str.parse::<usize>()?;
			let iscan_str = MiscError::from_option(cap.get(3),"Bad scan")?.as_str();
			let iscan = iscan_str.parse::<usize>()?;
			let ipix_str = MiscError::from_option(cap.get(4),"Bad pixel")?.as_str();
			let ipix = ipix_str.parse::<usize>()?;
			let id = format!("{}/{}/{}/{}",base,igra,iscan,ipix);
			let prefix = format!("{}-{}-{}-{}",base,igra_str,iscan_str,ipix_str);
			ids.insert(id);
			retrievals.push(Retrieval{
			    path:path.clone().into_os_string(),
			    prefix,
			    base:base.to_string(),
			    igra,
			    iscan,
			    ipix
			});
			count += 1;
		    }
		}
	    }
	}
    }

    // Figure out which MPKs to load
    let mpk_names : BTreeSet<String> =
	retrievals.iter().map(|r| r.base.clone()).collect();

    let mut index : BTreeMap<String,Footprint> = BTreeMap::new();

    // Load the footprints
    for name in mpk_names.iter() {
	let mut path : PathBuf = iasi_fp_dir.into();
	path.push(name);
	path.set_extension("mpk");
	let fps = Footprints::from_file(&path)?;

	let m = fps.footprints.len();

	// Filter footprints
	let mut m_kept = 0;
	for fp in fps.footprints.iter() {
	    let id = fp.id();
	    if ids.contains(id) {
		index.insert(id.to_string(),fp.clone());
		m_kept += 1;
	    }
	}
	info!("Loaded {} footprints from {:?}, kept {}",m,path,m_kept);
    }
	
    // Process retrievals
    let nret = retrievals.len();
    let mut footprints = Vec::new();
    let mut xch4_prior_arr = Array1::zeros(nret);
    let mut sigma_xch4_prior_arr = Array1::zeros(nret);
    let mut xch4_iasi_arr = Array1::zeros(nret);
    let mut sigma_xch4_iasi_arr = Array1::zeros(nret);
    let mut xch4_tropomi_arr = Array1::zeros(nret);
    let mut sigma_xch4_tropomi_arr = Array1::zeros(nret);
    let mut t_unix_arr = Array1::zeros(nret);
    let mut t_unix_tropomi_arr = Array1::zeros(nret);
    let mut lat_arr = Array1::zeros(nret);
    let mut lon_arr = Array1::zeros(nret);
    let mut lat_tropomi_arr = Array1::zeros(nret);
    let mut lon_tropomi_arr = Array1::zeros(nret);
    let mut converged_arr = Array1::from_elem(nret,false);
    let mut chi2_arr = Array1::zeros(nret);
    for (iret,Retrieval{ path,prefix,base,igra,iscan,ipix }) in retrievals.iter().enumerate() {
	info!("Opening retrieval file {:?}",path);
	let fd = hdf5::File::open(path)?;

	let converged : bool = fd.dataset("/res/converged")?.read_scalar()?;
	let chi2 : f64 = fd.dataset("/res/loss/value")?.read_scalar()?;
	let xstar : Array1<f64> = fd.dataset("/res/xstar")?.read_1d()?;
	let sxp : Array2<f64> = fd.dataset("/oi/sxp")?.read_2d()?;
	let xa : Array1<f64> = fd.dataset("/prior/mean")?.read_1d()?;
	let sx : Array2<f64> = fd.dataset("/prior/cov")?.read_2d()?;
	let im_ch4 = fd.group("/im/ch4")?;
	let ch4_i0 : usize = im_ch4.dataset("i0")?.read_scalar()?;
	let ch4_i1 : usize = im_ch4.dataset("i1")?.read_scalar()?;
	let operator_tc : Array1<f64> = im_ch4.dataset("units/ppmv_tc/operator")?.read_1d()?;

	let sx_ch4 = sx.slice(s![ch4_i0..ch4_i1,ch4_i0..ch4_i1]);
	let sxp_ch4 = sxp.slice(s![ch4_i0..ch4_i1,ch4_i0..ch4_i1]);

	let sigma_xch4_prior = operator_tc.dot(&sx_ch4.dot(&operator_tc)).sqrt();
	let sigma_xch4 = operator_tc.dot(&sxp_ch4.dot(&operator_tc)).sqrt();

	let xch4_prior = operator_tc.dot(&xa.slice(s![ch4_i0..ch4_i1]));
	let xch4 = operator_tc.dot(&xstar.slice(s![ch4_i0..ch4_i1]));

	let mut spc_path = PathBuf::from(input_dir);
	spc_path.push(format!("{}-spc.h5",prefix));
	info!("Opening spectrum file {:?}",spc_path);
	let spc_fd = hdf5::File::open(spc_path)?;
	let xch4_tropomi = spc_fd.dataset("/tropomi/xch4_corr")?.read_scalar()?;
	let sigma_xch4_tropomi = spc_fd.dataset("/tropomi/xch4_sigma")?.read_scalar()?;
	let t_unix = spc_fd.dataset("/t_unix")?.read_scalar()?;
	let t_unix_tropomi = spc_fd.dataset("/tropomi/t_unix")?.read_scalar()?;
	let lat = spc_fd.dataset("/lat")?.read_scalar()?;
	let lon = spc_fd.dataset("/lon")?.read_scalar()?;
	let lat_tropomi = spc_fd.dataset("/tropomi/lat")?.read_scalar()?;
	let lon_tropomi = spc_fd.dataset("/tropomi/lon")?.read_scalar()?;

	converged_arr[iret] = converged;
	chi2_arr[iret] = chi2;
	xch4_prior_arr[iret] = xch4_prior;
	sigma_xch4_prior_arr[iret] = sigma_xch4_prior;
	xch4_iasi_arr[iret] = xch4;
	sigma_xch4_iasi_arr[iret] = sigma_xch4;
	xch4_tropomi_arr[iret] = xch4_tropomi;
	sigma_xch4_tropomi_arr[iret] = sigma_xch4_tropomi;
	t_unix_arr[iret] = t_unix;
	t_unix_tropomi_arr[iret] = t_unix_tropomi;
	lat_arr[iret] = lat;
	lon_arr[iret] = lon;
	lat_tropomi_arr[iret] = lat_tropomi;
	lon_tropomi_arr[iret] = lon_tropomi;

	let id = format!("{}/{}/{}/{}",base,igra,iscan,ipix);
	if let Some(fp) = index.get(&id) {
	    let ffp = FancyFootprint {
		fp:(*fp).clone(),
		xch4,
		sigma_xch4,
		xch4_prior,
		sigma_xch4_prior,
		xch4_tropomi,
		sigma_xch4_tropomi,
		t_unix,
		t_unix_tropomi,
		lat,
		lon,
		lat_tropomi,
		lon_tropomi,
		converged,
		chi2
	    };
	    footprints.push(ffp);
	} else {
	    error!("Couldn't find footprint {}",id);
	}
    }

    let geojson_fn = format!("{}-footprints.geojson",out_base);
    info!("Exporting GeoJSON to {:?}",geojson_fn);
    footprint::export_geojson(&footprints,&geojson_fn)?;

    let cmp_fn = format!("{}-cmp.h5",out_base);
    info!("Exporting comparison data to {:?}",cmp_fn);
    let cmp_fd = hdf5::File::create(cmp_fn)?;

    fn wrg<T:hdf5::H5Type>(fd:&hdf5::File,name:&str,arr:&Array1<T>)->Result<(),Box<dyn Error>> {
	fd.new_dataset::<T>().create(name,arr.dim())?.write(arr.view())?;
	Ok(())
    }

    wrg(&cmp_fd,"xch4_prior",&xch4_prior_arr)?;
    wrg(&cmp_fd,"xch4_iasi",&xch4_iasi_arr)?;
    wrg(&cmp_fd,"xch4_tropomi",&xch4_tropomi_arr)?;
    wrg(&cmp_fd,"sigma_xch4_prior",&sigma_xch4_prior_arr)?;
    wrg(&cmp_fd,"sigma_xch4_iasi",&sigma_xch4_iasi_arr)?;
    wrg(&cmp_fd,"sigma_xch4_tropomi",&sigma_xch4_tropomi_arr)?;
    wrg(&cmp_fd,"t_unix",&t_unix_arr)?;
    wrg(&cmp_fd,"t_unix_tropomi",&t_unix_tropomi_arr)?;
    wrg(&cmp_fd,"lat",&lat_arr)?;
    wrg(&cmp_fd,"lon",&lon_arr)?;
    wrg(&cmp_fd,"lat_tropomi",&lat_tropomi_arr)?;
    wrg(&cmp_fd,"lon_tropomi",&lon_tropomi_arr)?;
    wrg(&cmp_fd,"converged",&converged_arr)?;
    wrg(&cmp_fd,"chi2",&chi2_arr)?;

    Ok(())
}
