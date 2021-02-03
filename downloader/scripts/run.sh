#!/bin/zsh

DATA_DIR=${DATA_DIR:-/aux/berke/data/}
OUT=${OUT_DIR:-work}
T_MIN=${T_MIN:-"2019-06-01 00:00:00 UTC"}
T_MAX=${T_MAX:-"2019-09-31 23:59:59 UTC"}

mkdir -p $OUT

if [ ! -e $OUT/tropomi-all.mpk ]; then
    target/release/fptool $DATA_DIR/coincidences/*/tropomi-*.mpk -c $OUT/tropomi-all.mpk
fi

if [ ! -e $OUT/iasi-all.mpk ]; then
    target/release/fptool $DATA_DIR/coincidences/*/iasi-*.mpk -c $OUT/iasi-all.mpk
fi

if [ ! -e $OUT/cris-all.mpk ]; then
    target/release/crisfpex $DATA_DIR/cris/GCRSO_*.h5 -o $OUT/cris-all.mpk
fi

for target in four-corners tar-sands ; do
    if [ ! -e $OUT/inter-$target.txt ]; then
	IN1=$OUT/tropomi-all.mpk IN2=$OUT/iasi-all.mpk OUT=$OUT/inter-$target.txt TARGET=$target \
	   DELTA_T=600.0 \
	   scripts/find-coincidences.sh 
    fi

    if [ ! -e $OUT/inter-$target.tracwiki ]; then
	awk -e 'BEGIN{ FS="\t" }
	    { if ("'$T_MIN'" <= $2 && $3 <= "'$T_MAX'") 
	      { printf("|| %04d || %s || %s || %.1f || %.3f || [[https://s5phub.copernicus.eu/dhus/search?q=%s|S5P]] || [[https://api.eumetsat.int/data/download/products/%s|IASI]] ||\n",$1,$2,$3,$4,$5,$6,$7) } }' \
	    $OUT/inter-$target.txt \
	    > $OUT/inter-$target.tracwiki
    fi
done
