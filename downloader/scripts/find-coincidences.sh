#!/bin/zsh

INTERSECT=${INTERSECT:-target/release/intersect}
IN1=${IN1:-iasi-all.mpk}
IN2=${IN2:-tropomi-all.mpk}
OUT=${OUT:-out.txt}

TARGET=${TARGET:-tar-sands}

case $TARGET in
    four-corners)
	LON0=${LON0:--109.6}
	LON1=${LON1:--107.0}
	LAT0=${LAT0:-36.2}
	LAT1=${LAT1:-37.4}
	;;
    tar-sands)
	LON0=${LON0:--112.0}
	LON1=${LON1:--111.0}
	LAT0=${LAT0:-56.6}
	LAT1=${LAT1:-57.5}
	;;
    *)
	echo "$0: Unknown target $TARGET" >&2
	exit 1
esac

mkdir -p $TARGET

$INTERSECT \
    --input1 $IN1 \
    --input2 $IN2 \
    --lat0 $LAT0 --lat1 $LAT1 --lon0 $LON0 --lon1 $LON1 \
    --delta-t 3600 \
    | tee $TARGET/$OUT
