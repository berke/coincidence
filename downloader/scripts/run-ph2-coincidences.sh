#!/bin/zsh

DATA_DIR=${DATA_DIR:-/aux/ph2coin}
OUT=${OUT:-out}
FPTOOL=${FPTOOL:-target/release/fptool}
RHO=${RHO:-0.0}
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
    while IFS=$'\t' read NUM T1 T2 X1 X2 X3 ID1 ID2 ; do
	kind_of $ID1
	K1=$kind
	kind_of $ID2
	K2=$kind
	IN1=$DATA_DIR/$K1/mpk/$ID1.mpk
	IN2=$DATA_DIR/$K2/mpk/$ID2.mpk
	if [ -e $IN1 ]; then
	    if [ -e $IN2 ]; then
		local out_base=$OUT/inter-$NUM
		mkdir -p $OUT

		if RHO=$RHO DELTA_T=$DELTA_T OUT=$out_base IN1=$IN1 IN2=$IN2 TARGET=$TARGET scripts/find-coincidences.sh >$out_base.log 2>&1 ; then
		    if [ -s $out_base.txt ]; then
			msg "Intersections found for $NUM ($ID1 vs $ID2)"
			echo $NUM $ID1 $ID2 >>$OUT/found.dat
		    else
			msg "No intersections found for $NUM ($ID1 vs $ID2)"
		    fi
		else
		    fail "Could not run coincidence script, see $out_base.log"
		fi
	    else
		msg "Skipping $NUM because second input file $IN2 is missing"
	    fi
	else
	    msg "Skipping $NUM because first input file $IN1 is missing"
	fi
    done
}

if [ -z "$TARGET" ]; then
    fail "Specify TARGET"
fi

if [ -z "$INTER" ]; then
    fail "Specify INTER"
fi

main <$INTER
