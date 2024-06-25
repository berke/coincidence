#!/bin/zsh

set -e

if [ -z "$1" ]; then
    echo "$0: Specify configuration as first argument" >&2
    exit 1
fi

source $1

HEADER_ONLY=${HEADER_ONLY:-0}

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

delay_min=2.0
delay_max=30
delay_alpha=1.05
delay_pause=30
#delay=$delay_min
delay=4.8828125

do_iasi() {
    local work=$WORK_DIR/$id
    
    mkdir -p $work
    touch $work/.this_is_a_work_dir

    local url="$EUMETSAT_BASE/$id/entry?name=$id.nat"

    trace "Need NAT file from $url"

    local nat_out=$IASI_SAVE/$id
    local nat_out_tmp=$IASI_SAVE/$id.tmp
    local curl_stderr=$work/.curl_stderr
    if [ -e $nat_out ]; then
	trace "File already downloaded as $nat_out"
    else
	trace "Re-downloading"
	while true ; do
	    msg "Sleeping for $delay"
	    sleep $delay

	    check_eumetsat_api_token
	    local curl_cmd=(
		curl
		   --max-time $CURL_MAX_TIME
		   --location
		   --tr-encoding
		   -f
		   -k -H "Authorization: Bearer $EUMETSAT_API_TOKEN"
		   "$url"
	    )
	    if (( HEADER_ONLY )) ; then
		$curl_cmd 2>$curl_stderr | head -c 4096 >$nat_out_tmp
	    else
		$curl_cmd 2>$curl_stderr -o $nat_out_tmp
	    fi

	    if [ $? = 0 ] && [ -s $nat_out_tmp ] ; then
		msg "Downloaded $id"
		   # "$url&access_token=$EUMETSAT_API_TOKEN" \
		mv $nat_out_tmp $nat_out
		confirm_eumetsat_api_token
		break
	    else
		rm -f $nat_out_tmp

		error "Could not download $url, RC $?"
		if grep -q '^curl:.*error: 429' $curl_stderr ; then
		    msg "Being rate limited"
		    sleep $delay_pause
		    (( delay=delay_alpha*delay ))
		    if (( delay > delay_max )) ; then
			delay=$delay_max
		    fi
		else
		    msg "Dropping token"
		    drop_eumetsat_api_token
		    sleep $delay_pause
		fi
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
