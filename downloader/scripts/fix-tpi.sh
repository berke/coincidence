#!/bin/zsh

DATA_DIR=${DATA_DIR:-/aux/ph2coin}

kind_of() {
    case $1 in
	S5P_*) kind=tropomi;;
	IASI_*) kind=iasi;;
	*) fail "Cannot identify kind from $1";;
    esac
}

main() {
    while read ID1 ID2 ; do
	kind_of $ID1
	K1=$kind
	IN1=$DATA_DIR/$K1/mpk-by-pixel/$ID1.mpk
	if [ ! -e $IN1 ]; then
	    pfx=$(echo -n $ID1 | sed -e 's/^S5P_OFFL_L1B_RA_BD7_\(..............._..............._....._..\)_\(.*\)$/S5P_OFFL_L2__CH4____\1/')
	    for x in $DATA_DIR/$K1/mpk-by-pixel/$pfx*.mpk(N) ; do
		ID1=${x:t:r}
	    done
	fi
	echo $ID1 $ID2
    done
}

if [ -z "$TPI" ]; then
    fail "Specify TPI"
fi

main <$TPI
