mod misc_error;

use misc_error::MiscError;
use std::error::Error;
use url::Url;

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
    Ok(())
}
