#!/bin/zsh

set -e

if [ -z "$1" ]; then
    echo "$0: Specify configuration as first argument" >&2
    exit 1
fi

source $1

msg() {
    echo "- $*"
    echo "$(date -Iseconds) MSG: $*" >>$LOG_FILE
}

mkdir -p $WORK_DIR

msg "Creating downloader configuration file"

OUT=${OUT:-$OUT_DIR/ph1}

mkdir -p $OUT

YEAR=$START_YEAR
MONTH=$START_MONTH
TROPOMI_MPKS=( )
IASI_MPKS=( )

while true ; do
    msg "Considering year $YEAR month $MONTH"
    MONTH=${(l:2::0:)MONTH}
    if [ -e $OUT/$YEAR-$MONTH ] ; then
       msg "Already downloaded $YEAR-$MONTH"
    else
	msg "Downloading $YEAR-$MONTH"

	DOWNLOAD_CFG=$WORK_DIR/download-$YEAR-$MONTH.cfg

	cat <<EOF >$DOWNLOAD_CFG
(
    draw_footprints:true,
    out_path:"$OUT",
    jobs:[
	Job(
	    year_month_range:(($YEAR,$MONTH),($YEAR,$MONTH)),
	    sources:[
		Tropomi((
		    base_url:"https://s5phub.copernicus.eu/dhus/search",
		    user_name:"s5pguest",
		    password:Some("s5pguest"),
		    platform_name:"Sentinel-5",
		    product_type:"L2__CH4___",
		    processing_mode:"Offline",
		    limit:None
		)),
		IASI((
		    collection:"EO%3AEUM%3ADAT%3AMETOP%3AIASIL1C-ALL",
		    base_url:"https://api.eumetsat.int/data/browse/collections",
		    limit:None
		))
	    ]
	)
    ]
)
EOF
	
	$DOWNLOADER $DOWNLOAD_CFG
    fi

    TROPOMI_MPKS=( $TROPOMI_MPKS $OUT/$YEAR-$MONTH/*.mpk )
    IASI_MPKS=( $IASI_MPKS $OUT/$YEAR-$MONTH/*.mpk )
    
    if (( YEAR == STOP_YEAR && MONTH == STOP_MONTH )) then
	break
    fi

    (( MONTH=MONTH + 1 ))
    if (( MONTH > 12 )) then
       MONTH=01
       (( YEAR=YEAR + 1 ))
    fi
done

mkdir -p $OUT/$TARGET

if [ ! -e $OUT/$TARGET/tropomi-all.mpk ]; then
    msg "Concatenating TROPOMI footprints"
    $FPTOOL $TROPOMI_MPKS -c $OUT/$TARGET/tropomi-all.mpk
fi

if [ ! -e $OUT/$TARGET/iasi-all.mpk ]; then
    msg "Concatenating IASI footprints"
    $FPTOOL $IASI_MPKS -c $OUT/$TARGET/iasi-all.mpk
fi

if [ ! -e $OUT/$TARGET/inter.txt ]; then
    msg "Running intersection tool"

    $INTERSECT \
	--input1 $OUT/$TARGET/tropomi-all.mpk \
	--input2 $OUT/$TARGET/iasi-all.mpk \
	--lat0 $LAT0 --lat1 $LAT1 --lon0 $LON0 --lon1 $LON1 \
	--delta-t $DELTA_T \
	--tau $TAU \
	--report $OUT/$TARGET/report.txt \
	--t-min $T_MIN \
	--t-max $T_MAX \
	--min-overlap $RHO \
	--output-base $OUT
fi
