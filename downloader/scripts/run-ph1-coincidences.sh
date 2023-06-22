#!/bin/zsh

set -e

OUT=$PH1_OUT_DIR

mkdir -p $OUT


if [ ! -e $OUT/inter-$target.txt ]; then
    IN1=$OUT/tropomi-all.mpk \
	IN2=$OUT/iasi-all.mpk \
	OUT=$OUT/inter-$target \
	RHO=0.001 \
	TARGET=$TARGET \
	DELTA_T=$DELTA_T \
	T_MIN=$T_MIN \
	T_MAX=$T_MAX \
	scripts/find-coincidences.sh 
fi

if [ ! -e $OUT/inter-$target.tracwiki ]; then
    awk -e 'BEGIN{ FS="\t" }
    { printf("|| %s || %s || %.1f || %.3f || [[https://s5phub.copernicus.eu/dhus/search?q=%s|S5P]] || [[https://api.eumetsat.int/data/download/products/%s|IASI]] || %04d ||\n",$2,$3,$4,$5,$7,$8,$1) }' \
	$OUT/inter-$target.txt \
	| sort > $OUT/inter-$target.tracwiki
fi

for x in $OUT/inter-$target-*.mpk ; do
    if [ ! -e ${x:r}.json ]; then
	$FPTOOL $x -e ${x:r}.json
    fi
done
