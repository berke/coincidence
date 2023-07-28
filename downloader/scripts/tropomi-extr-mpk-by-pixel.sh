#!/bin/zsh

set -e

if [ -z "$1" ]; then
    echo "$0: Specify configuration as first argument" >&2
    exit 1
fi

source $1
shift

num_errors=0

fail() {
    echo "FAILURE: $*" >&2
    echo "$(date -Iseconds) FAILURE: $*" >>$ERROR_LOG_FILE
    echo "$(date -Iseconds) FAILURE: $*" >>$LOG_FILE
    exit 1
}

msg() {
    echo "- $*"
    echo "$(date -Iseconds) MSG: $*" >>$LOG_FILE
}

error() {
    num_errors=$(( num_errors + 1 ))
    echo "$(date -Iseconds) ERROR: $*" >>$ERROR_LOG_FILE
    echo "ERROR: $*"
}

trace() {
    if [ "$TRACE" = 1 ]; then
	echo "$(date -Iseconds) TRACE: $*" >>$LOG_FILE
	echo "TRACE: $*"
    fi
}

while read -A a ; do
    orbit=$a[1]
    sel=( $a[2,$#a] )
    echo "Orbit: $orbit selection: $sel"
    for nc in $TROPOMI_SAVE/S5P_???????????????????????????????????????????????_${orbit}_?????????????????????????.nc ; do
	echo "Found $nc"
	id=${nc:t:r}
	local work=$WORK_DIR/
	local tmp_mpk=$work/$id.mpk
	local tmp_mpk_log=$work/$id.mpk.log
	# local out=$OUT/tropomi/mpk-by-pixel
	mkdir -p $out
	if [ -e $out/$id.mpk ]; then
	    trace "Skipping already processed footprint $id at $out/$id.mpk"
	else
	    if ! $TROPOMIFPEX --by-pixel \
		 --output $tmp_mpk \
		 --selection $sel \
		 -- $nc >$tmp_mpk_log 2>&1 ; then
		error "Could not extract MPK from NC for $id, RC $?; see log file $tmp_mpk_log"
		continue
	    fi
	    mv $tmp_mpk $out/$id.mpk
	    rm -f $tmp_nc_log
	fi
    done
done
