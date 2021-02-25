#!/bin/zsh

set -e

DATA_DIR=${DATA_DIR:-/aux/berke/data/}
OUT=${OUT_DIR:-work5}
T_MIN=${T_MIN:-"2019-06-01T00:00:00"}
T_MAX=${T_MAX:-"2019-10-01T00:00:00"}

mkdir -p $OUT

if [ ! -e $OUT/tropomi-all.mpk ]; then
    target/release/fptool $DATA_DIR/coincidences/*/tropomi-*.mpk -c $OUT/tropomi-all.mpk
fi

if [ ! -e $OUT/iasi-all.mpk ]; then
    target/release/fptool $DATA_DIR/coincidences/*/iasi-*.mpk -c $OUT/iasi-all.mpk
fi

# if [ ! -e $OUT/cris-all.mpk ]; then
#     target/release/crisfpex $DATA_DIR/cris/GCRSO_*.h5 -o $OUT/cris-all.mpk
# fi

(cat <<EOF
four-corners 4800
tar-sands 3600
EOF
) | while read target delta_t ; do
    echo $target $delta_t
    if [ ! -e $OUT/inter-$target.txt ]; then
	IN1=$OUT/tropomi-all.mpk \
	   IN2=$OUT/iasi-all.mpk \
	   OUT=$OUT/inter-$target \
	   TARGET=$target \
	   DELTA_T=$delta_t \
	   T_MIN=$T_MIN \
	   T_MAX=$T_MAX \
	   scripts/find-coincidences.sh 
    fi

    if [ ! -e $OUT/inter-$target.tracwiki ]; then
	awk -e 'BEGIN{ FS="\t" }
    { printf("|| %s || %s || %.1f || %.3f || [[https://s5phub.copernicus.eu/dhus/search?q=%s|S5P]] || [[https://api.eumetsat.int/data/download/products/%s|IASI]] || %04d ||\n",$2,$3,$4,$5,$6,$7,$1) }' \
	    $OUT/inter-$target.txt \
	    | sort > $OUT/inter-$target.tracwiki
    fi

    for x in $OUT/inter-$target-*.mpk ; do
	if [ ! -e ${x:r}.json ]; then
	    target/release/fptool $x -e ${x:r}.json
	fi
    done
done
