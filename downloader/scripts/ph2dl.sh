#!/bin/zsh

set -e

if [ -z "$1" ]; then
    echo "$0: Specify configuration as first argument" >&2
    exit 1
fi

source $1

IASI_ENABLE=${IASI_ENABLE:-1}
TROPOMI_ENABLE=${TROPOMI_ENABLE:-1}

num_errors=0
tropomi_count=0
iasi_count=0

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
    if [ ! -x $IASINAT2NEX ]; then
	fail "Specify path to iasinat2nex tool in IASINAT2NEX"
    fi

    if [ ! -x $IASIFPEX ]; then
	fail "Specify path to iasifpex tool in IASIFPEX"
    fi

    if [ ! -x $TROPOMIFPEX ]; then
	fail "Specify path to tropomifpex tool in TROPOMIFPEX"
    fi

    if [ ! -x $S5PDOWNLOAD ]; then
	fail "Specify path to s5pdownload tool in S5PDOWNLOAD"
    fi
}

safe_rm_rf() {
    trace "Removing $1"
    rm -rf $1
}

bump_cache() {
    if [ ! -e $CACHEDIR ]; then
	mkdir -p $CACHEDIR
	return
    fi
    
    local last_used=x
    while true ; do
	local used=$(du -B 1024 -sx $CACHEDIR | awk '{print $1}')
	if [ $((used >> 10)) -lt $CACHE_MAX_MB ]; then
	    trace "Cache usage is $used"
	    return
	fi
	trace "Cache usage $used exceeds limit, will clean up"
	if [ $last_used != x ]; then
	    if [ ! $used -lt $last_used ]; then
		fail "No progress in clearing cache"
	    fi
	fi
		
	local candidate=$(ls -tN $CACHEDIR|tail -1)
	if [ ! -z "$candidate" ]; then
	    trace "Bumping $candidate from cache"
	    rm -f $CACHEDIR/$candidate
	else
	    fail "No more candidates to purge from cache"
	fi

	last_used=$used
    done
}

fail_work_dir() {
    local target=$FAILURE_DIR/${work}_$(date +%s)
    msg "Moving failed work directory $work to $target"
    mkdir -p $FAILURE_DIR
    mv $work $target
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

delete_work_dir() {
    if [ -e $work/.this_is_a_work_dir ]; then
	trace "Cleaning work directory $work"
	safe_rm_rf $work
    else
	if rmdir $work ; then
	    trace "Removed empty directory $work"
	else
	    fail "Directory $work does not contain the marker file and is not empty"
	fi
    fi
}

process() {
    msg "Processor called"

    if [ $processor_done = 1 ]; then
	trace "Processor aleady ran, ignoring"
	return
    fi

    case $FORMAT in
	netCDF) ;;
	*)
	    error "Unsupported format $FORMAT"
	    return
	    ;;
    esac

    msg "Need netCDF file from $URL"

    local nc_out=$CACHEDIR/$FILE
    local nc_out_tmp=$CACHEDIR/$FILE.tmp

    if [ -e $nc_out ]; then
	trace "File present in cache"
    else
	trace "Re-downloading"
	bump_cache
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

    local mpk_out_tmp=$work/$id.mpk
    local tropomifpex_log=$work/tropomifpex.log
    if $TROPOMIFPEX $nc_out -o $mpk_out_tmp >$tropomifpex_log 2>&1 ; then
	msg "Extracted footprints for $id into $mpk_out_tmp"
	mkdir -p ${mpk_out:h}
	mv $mpk_out_tmp $mpk_out
	processor_error=0
    else
	error "Could not extract footprints, RC $?, see $tropomifpex_log"
	processor_error=1
    fi

    processor_done=1
}

do_tropomi() {
    if [ $TROPOMI_ENABLE = 0 ]; then
	msg "TROPOMI disabled via TROPOMI_ENABLE"
	return
    fi

    local work=$WORK_DIR/$id
    local mpk_out=$OUT_DIR/tropomi/mpk/$id.mpk

    if [ -e $mpk_out ]; then
	trace "Footprints have already been extracted for $id"
	tropomi_count=$((tropomi_count + 1))
	return
    fi

    if [ -e $work ]; then
	trace "Work directory $work already exists, deleting"
	delete_work_dir
    fi
    
    mkdir -p $work
    touch $work/.this_is_a_work_dir

    trace "Searching UUID for TROPOMI observation $id"

    local s5pdownload_out=$work/process.sh
    local s5pdownload_log=$work/s5pdownload.log
    if $S5PDOWNLOAD --output $s5pdownload_out $id >$s5pdownload_log 2>&1 ; then
	trace "Sourcing $s5pdownload_out"
	processor_error=0
	processor_done=0
	source $s5pdownload_out
	if [ $processor_done = 0 ]; then
	    error "Did not complete"
	    fail_work_dir
	    return
	fi
	if [ $processor_error = 0 ]; then
	    trace "Extraction completed"
	    tropomi_count=$((tropomi_count + 1))
	else
	    error "Extraction failed"
	    fail_work_dir
	fi
    else
	error "Could not get UUID for $id, see $s5pdownload_log"
	fail_work_dir
    fi
}

eumetsat_api_token_drop_count=0

drop_eumetsat_api_token() {
    msg "Dropping EUMETSAT API token"
    if [ $eumetsat_api_token_drop_count != 0 ] ; then
	msg "Already dropped token, going into timeout"
	throttle_fail
    fi
    EUMETSAT_API_TOKEN=
    EUMETSAT_API_TOKEN_T=
}

confirm_eumetsat_api_token() {
    eumetsat_api_token_drop_count=0
    throttle_ok
}

refresh_eumetsat_api_token() {
    if curl -f -k -d "grant_type=client_credentials" \
	    -H "Authorization: Basic $EUMETSAT_API_AUTH" \
	    https://api.eumetsat.int/token >$WORK_DIR/eumetsat_api.token ; then
	EUMETSAT_API_TOKEN=$(sed -ne 's/^.*"access_token":"\([0-9a-z-]\+\)\".*$/\1/p' $WORK_DIR/eumetsat_api.token)
	EUMETSAT_API_TOKEN_T=$(date +%s)
	msg "Got new EUMETSAT API token $EUMETSAT_API_TOKEN"
    else
	fail "Could not get token"
    fi
}

check_eumetsat_api_token() {
    if [ -z "$EUMETSAT_API_TOKEN" ]; then
	trace "No EUMETSAT API token"
	refresh_eumetsat_api_token
    else
	local t_now=$(date +%s)
	if [ $t_now -gt $((EUMETSAT_API_TOKEN_T + EUMETSAT_API_TOKEN_VALIDITY)) ]; then
	    trace "EUMETSAT API token expired or about to expire soon"
	    refresh_eumetsat_api_token
	else
	    trace "EUMETSAT API token should be valid"
	fi
    fi
}

do_iasi() {
    if [ $IASI_ENABLE = 0 ]; then
	msg "IASI disabled via IASI_ENABLE"
	return
    fi
    
    local work=$WORK_DIR/$id
    local nex_out=$OUT_DIR/iasi/nex/$id.nex
    local mpk_out=$OUT_DIR/iasi/mpk/$id.mpk

    if [ -e $mpk_out ]; then
	trace "Footprints have already been extracted for $id"
	iasi_count=$((iasi_count + 1))
	return
    fi

    if [ -e $work ]; then
	trace "Work directory $work already exists, deleting"
	delete_work_dir
    fi
    
    mkdir -p $work
    touch $work/.this_is_a_work_dir

    if [ ! -e $nex_out ]; then
	local url=$EUMETSAT_BASE/$id

	msg "Need NAT file from $url"

	local natzip_out=$CACHEDIR/$id
	local natzip_out_tmp=$CACHEDIR/$id.tmp
	if [ -e $natzip_out ]; then
	    trace "File present in cache"
	else
	    trace "Re-downloading"
	    bump_cache
	    while true ; do
		check_eumetsat_api_token
		if curl \
		       --max-time $CURL_MAX_TIME \
		       --location \
		       -f \
		       -k -H "Authorization: Bearer $EUMETSAT_API_TOKEN" \
		       $EUMETSAT_BASE/$id \
		       -o $natzip_out_tmp ; then
		    msg "Downloaded"
		    mv $natzip_out_tmp $natzip_out
		    confirm_eumetsat_api_token
		    break
		else
		    error "Could not download $url, RC $?"
		    drop_eumetsat_api_token
		fi
	    done
	fi

	local nat_out=$work/$id.nat
	msg "Unzipping..."
	if unzip -n -qq $natzip_out $id.nat -d $work ; then
	    trace "Unzipped into $nat_out"
	else
	    error "Could not unzip $id, RC $?";
	    fail_work_dir $work
	    return
	fi

	local iasinat2nex_log=$work/iasinat2nex.log
	local nex_out_tmp=$work/$id.nex.tmp
	if $IASINAT2NEX $nat_out $nex_out_tmp >$iasinat2nex_log 2>&1 ; then
	    trace "Extracted as ASCII into $nex_out_tmp"
	    mkdir -p ${nex_out:h}
	    mv $nex_out_tmp $nex_out
	else
	    error "Could not extract, RC $?, see $iasinat2nex_log"
	    fail_work_dir
	    return
	fi
    fi

    local iasifpex_log=$work/iasifpex.log
    local mpk_out_tmp=$work/$id.mpk
    if $IASIFPEX $nex_out --output $mpk_out_tmp >$iasifpex_log 2>&1 ; then
	msg "Extracted footprints for $id into $mpk_out_tmp"
	mkdir -p ${mpk_out:h}
	mv $mpk_out_tmp $mpk_out
	iasi_count=$((iasi_count + 1))
    else
	error "Could not extract footprints, RC $?, see $iasifpex_log"
	fail_work_dir
	return
    fi

    delete_work_dir
}

main() {
    mkdir -p $WORK_DIR

    if [ -z "$INTER" ]; then
	fail "Specify intersections file via environment variable INTER"
    fi

    msg "Work directory: $WORK_DIR"
    msg "Intersections file: $INTER"
    check_tools

    ids=( $(awk -e 'BEGIN{ FS="\t"} {print $7;print $8}' $INTER | sort -u) )

    for id in $ids ; do
	trace "Considering $id"
	case $id in
	    S5P*) do_tropomi;;
	    IASI*) do_iasi;;
	    *) fail "Could not figure out ID $id"
	esac
    done

    msg "Total TROPOMI count: $tropomi_count"
    msg "Total IASI count: $iasi_count"
}

main
