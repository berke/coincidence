#!/bin/zsh

DATA_DIR=${DATA_DIR:-/aux/ph2coin}
OUT=${OUT:-out}
RHO=${RHO:-0.99}
OMEGA=${OMEGA:-0.99}
DELTA_T=${DELTA_T:-3600}

fail() {
    echo "FAILURE: $*" >&2
    exit 1
}

msg() {
    echo "- $*"
}

error() {
    echo "ERROR: $*"
}

trace() {
    if [ "$TRACE" = 1 ]; then
	echo "TRACE: $*"
    fi
}

kind_of() {
    case $1 in
	S5P_*) kind=tropomi;;
	IASI_*) kind=iasi;;
	*) fail "Cannot identify kind from $1";;
    esac
}

main() {
    num=0
    while read ID1 ID2 ; do
 
 	num=$(( num + 1 ))
 	NUM=$(printf %06d $num)
 	kind_of $ID1
 	K1=$kind
 	kind_of $ID2
 	K2=$kind
 	IN1=$DATA_DIR/$K1/mpk-by-pixel/$ID1.mpk
 	IN2=$DATA_DIR/$K2/mpk-by-pixel/$ID2.mpk
 	if [ -e $IN1 ]; then
 	    if [ -e $IN2 ]; then
 		local out_base=$OUT/inter-$NUM
 		mkdir -p $OUT
 
 		echo "RHO=$RHO \
 		      DELTA_T=$DELTA_T \
 		      OUT=$out_base \
 		      IN1=$IN1 \
 		      IN2=$IN2 \
 		      TARGET=$TARGET \
 		      scripts/find-coincidences.sh \
 		      --rho-by-fp \
 		      --omega $OMEGA >$out_base.log 2>&1"
 	    else
 		msg "Skipping line $NUM because second input file $IN2 is missing"
 	    fi
 	else
 	    msg "Skipping line $NUM because first input file $IN1 is missing"
 	fi
    done
}

if [ -z "$TARGET" ]; then
    fail "Specify TARGET"
fi

if [ -z "$TPI" ]; then
    fail "Specify TPI"
fi

main <$TPI
#| parallel
