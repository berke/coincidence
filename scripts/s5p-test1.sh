#!/bin/zsh

#URL="https://scihub.copernicus.eu/dhus/search"
URL="https://s5phub.copernicus.eu/dhus/search"

#Q='producttype:"Sentinel-5 Precursor" AND beginposition:2018-05-01T11:11:11.111Z TO 2018-05-01T11:21:11.111Z'
Q='platformname:Sentinel-5 AND (producttype:L1B_RA_BD7 OR producttype:L1B_RA_BD8) AND processinglevel:L1B AND processingmode:Offline AND orbitnumber:15839'
#Q='producttype:"L1B_RA_BD7"'
#Q='beginposition:[2018-05-01T11:11:11.111Z TO 2018-05-01T11:21:11.111Z]
#Q='*'

USER=s5pguest
PASSWORD=s5pguest

#curl -u $USER:$PASSWORD -g "$URL?q=$Q" >out
wget --user $USER --password $PASSWORD "$URL?q=$Q" -O out
#cat out
