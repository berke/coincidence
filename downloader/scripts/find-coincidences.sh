#!/bin/zsh

set -e

INTERSECT=${INTERSECT:-target/release/intersect}
IN1=${IN1:-iasi-all.mpk}
IN2=${IN2:-tropomi-all.mpk}
OUT=${OUT:-out}
DELTA_T=${DELTA_T:-3600.0}
TAU=${TAU:-0.00}
PSI=${PSI:-0.50}
OMEGA=${OMEGA:-1e-3}

if [ -z "$TARGET" ]; then
    echo "$0: Specify target name via variable TARGET" >&2
    exit 1
fi

mkdir -p $TARGET

$INTERSECT \
    --input1 $IN1 \
    --input2 $IN2 \
    --lat0 $LAT0 --lat1 $LAT1 --lon0 $LON0 --lon1 $LON1 \
    --delta-t-max $DELTA_T \
    --tau $TAU \
    --report $OUT.txt \
    --t-min $T_MIN \
    --t-max $T_MAX \
    --psi-min $PSI \
    --omega-min $OMEGA \
    --output-base $OUT \
    $*
