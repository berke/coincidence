#!/bin/zsh

set -e

if [ -z "$1" ]; then
    echo "$0: Specify configuration as first argument" >&2
    exit 1
fi

source $1

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

check_tools() {
    if [ ! -x $S5PDOWNLOAD ]; then
	fail "Specify path to s5pdownload tool in S5PDOWNLOAD"
    fi
}

throttle_min=60
throttle_max=3600
throttle_current=$throttle_min

throttle_fail() {
    throttle_current=$((throttle_current * 2))
    if [ $throttle_current -gt $throttle_max ]; then
	throttle_current=$throttle_max
    fi
    msg "Throttling for $throttle_current seconds..."
    sleep $throttle_current
}

throttle_ok() {
    throttle_current=$((throttle_current / 2))
    if [ $throttle_current -lt $throttle_min ]; then
	throttle_current=$throttle_min
    fi
}

process() {
    msg "Processor called on $FILE"

    case $FORMAT in
	netCDF) ;;
	*)
	    error "Unsupported format $FORMAT"
	    return
	    ;;
    esac

    msg "Need netCDF file from $URL"

    local nc_out=$TROPOMI_SAVE/$FILE
    local nc_out_tmp=$nc_out.tmp

    if [ -e $nc_out ]; then
	trace "File already downloaded"
    else
	trace "Downloading to $nc_out"
	while true ; do 
	    if curl \
		   -u $S5P_AUTH \
		   --max-time $CURL_MAX_TIME \
		   --location \
		   -f \
		   -k \
		   $URL \
		   -o $nc_out_tmp ; then
		msg "Downloaded"
		mv $nc_out_tmp $nc_out
		throttle_ok
		break
	    else
		error "Could not download $URL, RC $?"
		throttle_fail
	    fi
	done
    fi

    processor_done=1
}

main() {
    mkdir -p $WORK_DIR

    if [ -z "$SCRIPT" ]; then
	fail "Specify file containing s5pdownload output via environment variable SCRIPT"
    fi

    msg "Work directory: $WORK_DIR"
    check_tools

    source $SCRIPT
}

main
