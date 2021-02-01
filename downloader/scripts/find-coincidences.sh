#!/bin/zsh

INTERSECT=${INTERSECT:-target/release/intersect}
IN1=${IN1:-iasi-all.mpk}
IN2=${IN2:-tropomi-all.mpk}
OUT=${OUT:-out.txt}

# Four corners

LON0=${LON0:--109.6}
LON1=${LON1:--107.0}
LAT0=${LAT0:-36.2}
LAT1=${LAT1:-37.4}

$INTERSECT \
    --input1 $IN1 \
    --input2 $IN2 \
    --lat0 $LAT0 --lat1 $LAT1 --lon0 $LON0 --lon1 $LON1 \
    --delta-t 3600 \
    | tee $OUT
