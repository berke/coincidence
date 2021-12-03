#!/bin/zsh

set -e

INTERSECT=${INTERSECT:-target/release/intersect}
IN1=${IN1:-iasi-all.mpk}
IN2=${IN2:-tropomi-all.mpk}
OUT=${OUT:-out}
DELTA_T=${DELTA_T:-3600.0}
TAU=${TAU:-0.00}
RHO=${RHO:-0.50}
T_MIN=${T_MIN:-"2019-06-01T00:00:00"}
T_MAX=${T_MAX:-"2019-10-01T00:00:00"}

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
    siberia)
	LON0=${LON0:-62.0}
	LON1=${LON1:-82.0}
	LAT0=${LAT0:-53.0}
	LAT1=${LAT1:-63.0}
	;;
    anywhere)
	LON0=${LON0:--180.0}
	LON1=${LON1:-180.0}
	LAT0=${LAT0:--90.0}
	LAT1=${LAT1:-90.0}
	;;
    specific)
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
    --delta-t $DELTA_T \
    --tau $TAU \
    --report $OUT.txt \
    --t-min $T_MIN \
    --t-max $T_MAX \
    --min-overlap $RHO \
    --output-base $OUT
