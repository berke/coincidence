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

main() {
    for nat in $* ; do
	echo $nat
	id=${nat:t}
	local work=$WORK_DIR/
	local tmp_nex=$work/$id.nex
	local tmp_nex_log=$work/$id.nex.log
	local tmp_mpk=$work/$id.mpk
	local tmp_mpk_log=$work/$id.mpk.log
	local out=$OUT_DIR/iasi/mpk-by-pixel
	if [ -e $out/$id.mpk ]; then
	    trace "Skipping already processed $nat"
	else
	    trace "Processing $nat"
	    if ! $IASINAT2NEX $nat $tmp_nex >$tmp_nex_log 2>&1 ; then
		error "Could not extract NEX from NAT for $id, RC $?"
		continue
	    fi
	    if ! $IASIFPEX --by-pixel --output $tmp_mpk $tmp_nex >$tmp_mpk_log 2>&1 ; then
		error "Could not extract MPK from NEX for $id, RC $?"
		continue
	    fi
	    mv $tmp_mpk $out/$id.mpk
	    rm -f $tmp_nex $tmp_nex_log $tmp_mpk_log
	fi
    done
}

main $*
