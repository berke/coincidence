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
    if curl -q -f -k -d "grant_type=client_credentials" \
	    -H "Authorization: Basic $EUMETSAT_API_AUTH" \
	    https://api.eumetsat.int/token >$WORK_DIR/eumetsat_api.token ; then
	EUMETSAT_API_TOKEN=$(sed -ne 's/^.*"access_token":"\([0-9a-z-]\+\)\".*$/\1/p' $WORK_DIR/eumetsat_api.token)
	EUMETSAT_API_TOKEN_T=$(( $(date +%s) + $(sed -ne 's/^.*"expires_in":\([0-9]\+\).*$/\1/p' $WORK_DIR/eumetsat_api.token)))
	msg "Got new EUMETSAT API token $EUMETSAT_API_TOKEN valid until $(date -d @$EUMETSAT_API_TOKEN_T)"
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
	if [ $t_now -gt $EUMETSAT_API_TOKEN_T ]; then
	    trace "EUMETSAT API token expired or about to expire soon"
	    refresh_eumetsat_api_token
	else
	    trace "EUMETSAT API token should be valid"
	fi
    fi
}

do_iasi() {
    local work=$WORK_DIR/$id
    
    mkdir -p $work
    touch $work/.this_is_a_work_dir

    local url="$EUMETSAT_BASE/$id/entry?name=$id.nat"

    msg "Need NAT file from $url"

    local nat_out=$IASI_SAVE/$id
    local nat_out_tmp=$IASI_SAVE/$id.tmp
    if [ -e $nat_out ]; then
	trace "File already downloaded"
    else
	trace "Re-downloading"
	while true ; do
	    check_eumetsat_api_token
	    if curl \
		   --max-time $CURL_MAX_TIME \
		   --location \
		   -f \
		   -k -H "Authorization: Bearer $EUMETSAT_API_TOKEN" \
		   "$url&access_token=$EUMETSAT_API_TOKEN" \
		   -o $nat_out_tmp ; then
		msg "Downloaded"
		mv $nat_out_tmp $nat_out
		confirm_eumetsat_api_token
		break
	    else
		error "Could not download $url, RC $?"
		sleep 5
		drop_eumetsat_api_token
	    fi
	done
    fi
}

main() {
    mkdir -p $WORK_DIR

    if [ -z "$IDS" ]; then
	fail "Specify file containing IASI file IDs via environment variable IDS"
    fi

    msg "Work directory: $WORK_DIR"

    ids=( $(cat $IDS | sort -u) )

    for id in $ids ; do
	do_iasi
    done
}

main
