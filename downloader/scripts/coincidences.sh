#!/bin/zsh

set -e

if [ -z "$1" ]; then
    echo "$0: Specify configuration as first argument" >&2
    exit 1
fi

CONFIG=$1

source $CONFIG

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
    if [ -e $OUT/$YEAR-$MONTH/.completed ] ; then
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
		    limit:None,
		    num_retries:5,
		    initial_timeout:2.0
		))
	    ]
	)
    ]
)
EOF
	
	$DOWNLOADER $DOWNLOAD_CFG
	touch $OUT/$YEAR-$MONTH/.completed
    fi

    TROPOMI_MPKS=( $TROPOMI_MPKS $OUT/$YEAR-$MONTH/tropomi-*.mpk )
    IASI_MPKS=( $IASI_MPKS $OUT/$YEAR-$MONTH/iasi-*.mpk )
    
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

INTER=$OUT/$TARGET/inter.txt

if [ ! -e $INTER ]; then
    msg "Running intersection tool"

    $INTERSECT \
	--input1 $OUT/$TARGET/tropomi-all.mpk \
	--input2 $OUT/$TARGET/iasi-all.mpk \
	--lat0 $LAT0 --lat1 $LAT1 --lon0 $LON0 --lon1 $LON1 \
	--delta-t $DELTA_T \
	--tau $TAU \
	--report $INTER \
	--t-min $T_MIN \
	--t-max $T_MAX \
	--min-overlap $RHO_PH1 \
	--output-base $OUT/$TARGET/inter
fi

if [ ! -e $OUT/$TARGET/inter.tracwiki ]; then
    awk -e 'BEGIN{ FS="\t" }
    { printf("|| %s || %s || %.1f || %.3f || [[https://s5phub.copernicus.eu/dhus/search?q=%s|S5P]] || [[https://api.eumetsat.int/data/download/products/%s|IASI]] || %04d ||\n",$2,$3,$4,$5,$7,$8,$1) }' \
	$INTER | sort > $OUT/$TARGET/inter.tracwiki
fi

msg "Starting phase 2"
INTER=$INTER scripts/ph2dl.sh $CONFIG

OUT2=$OUT_DIR/ph2
mkdir -p $OUT2/$TARGET

# Compute unique product pairs
PAIRS=$OUT2/$TARGET/product-pairs.txt
msg "Computing unique product pairs, saving to $PAIRS from $INTER"

(while IFS=$'\t' read NUM T1 T2 X1 X2 X3 ID1 ID2 LAT LON ; do
     echo "$ID1 $ID2"
 done) <$INTER >$PAIRS

kind_of() {
    case $1 in
	S5P_*) kind=tropomi;;
	IASI_*) kind=iasi;;
	*) fail "Cannot identify kind from $1";;
    esac
}

# Run tool
FOUND=$OUT2/$TARGET/found.dat

if [ -e $FOUND ]; then
    msg "Phase 2 intersections already computed in $FOUND"
else
    rm -f $FOUND.tmp
    touch $FOUND.tmp

    msg "Computing intersections"
    NUM=0
    (while read ID1 ID2 ; do
	 kind_of $ID1
	 K1=$kind
	 kind_of $ID2
	 K2=$kind
	 IN1=$OUT_DIR/ph2/$K1/mpk/$ID1.mpk
	 IN2=$OUT_DIR/ph2/$K2/mpk/$ID2.mpk

	 local out_base=$OUT2/$TARGET/inter-$NUM
	 mkdir -p $OUT
	 (( NUM=NUM+1 ))
	 NUM=${(l:6::0:)NUM}

	 echo $INTERSECT \
	     --input1 $IN1 \
	     --input2 $IN2 \
	     --lat0 $LAT0 --lat1 $LAT1 --lon0 $LON0 --lon1 $LON1 \
	     --delta-t $DELTA_T \
	     --tau $TAU \
	     --report $out_base.txt \
	     --t-min $T_MIN \
	     --t-max $T_MAX \
	     --min-overlap $RHO_PH2 \
	     --output-base $out_base
     done) <$PAIRS | parallel

    NUM=0
    (while read ID1 ID2 ; do
	 (( NUM=NUM+1 ))
	 NUM=${(l:6::0:)NUM}
	 local out_base=$OUT2/$TARGET/inter-$NUM
	 if [ -s $out_base.txt ]; then
	     msg "Intersections found for $NUM ($ID1 vs $ID2)"
	     echo $NUM $ID1 $ID2 >>$FOUND.tmp
	 else
	     msg "No intersections found for $NUM ($ID1 vs $ID2)"
	 fi
     done) <$PAIRS

    mv $FOUND.tmp $FOUND
fi

# 

IASI_NATS=$OUT2/$TARGET/iasi-nats.txt
S5P_NCS=$OUT2/$TARGET/s5p-ncs.txt
S5P_ORBITS=$OUT2/$TARGET/s5p-orbits.txt
S5P_SCRIPT=$OUT2/$TARGET/s5p-script

if [ ! -e $IASI_NATS ]; then
    msg "Computing unique promising IASI product IDs"
    cut -f3 -d\  $FOUND | sort -u >$IASI_NATS
fi

if [ ! -e $S5P_NCS ]; then
    msg "Computing unique promising S5P product IDs and orbit numbers"
    cut -f2 -d\  $FOUND | sort -u >$S5P_NCS
    cut -c53-57 $S5P_NCS | sort -u >$S5P_ORBITS
fi

if [ ! -e $S5P_SCRIPT ]; then
    msg "Determining S5P download URLs"
    $S5PDOWNLOAD --output $S5P_SCRIPT $(cat $S5P_ORBITS)
fi

msg "Launching IASI L1C downloads"
IDS=$IASI_NATS scripts/iasi-l1c-download.sh $CONFIG

msg "Launching S5P L2 downlads"
SCRIPT=$S5P_SCRIPT scripts/tropomi-l2-download.sh $CONFIG

msg "Extracting IASI per-pixel footprints"
NAT_ROOT=$OUT_DIR/iasi/nat out=$OUT2/$TARGET/iasi/mpk-by-pixel \
			   scripts/iasi-extr-mpk-by-pixel.sh $CONFIG \
			   $(cat $IASI_NATS)

# XXXXXXXXX This needs to be done on phase 2 results
S5P_FOI=$OUT2/$TARGET/s5p-foi.txt
if [ ! -e $S5P_FOI ]; then
    msg "Compiling list of S5P footprints of interest"
    cat $OUT2/$TARGET/inter-??????.txt |
	cut -f7 -d$'\t' |
	sed -e 's@^\([^/]*\)/\([0-9]*\)/\([0-9]*\)\t.*$@\1 \2 \3@p' |
	cut -c53-57,84- |
	tr / ' ' |
	sort -u |
	awk 'BEGIN{prev=-1} { if($1 != prev) { prev=$1;printf("\n%d",prev); } printf(" %d,%d",$2,$3) }' |
	grep -v '^$' >$S5P_FOI
fi

msg "Extracting S5P per-pixel footprints"
echo "out=$OUT2/$TARGET/tropomi/mpk-by-pixel scripts/tropomi-extr-mpk-by-pixel.sh $CONFIG <$S5P_FOI"
out=$OUT2/$TARGET/tropomi/mpk-by-pixel scripts/tropomi-extr-mpk-by-pixel.sh $CONFIG <$S5P_FOI

msg "Computing per-pixel coincidences"
PPC_CMD=$OUT2/$TARGET/run-pixel-coincidences.cmd

OUT3=$OUT_DIR/ph3
mkdir -p $OUT3/$TARGET

rm -f $PPC_CMD

NUM=0
(while read ID1 ID2 ; do
     (( NUM=NUM+1 ))
     kind_of $ID1
     K1=$kind
     kind_of $ID2
     K2=$kind
     IN1=$OUT2/$TARGET/$K1/mpk-by-pixel/$ID1.mpk
     IN2=$OUT2/$TARGET/$K2/mpk-by-pixel/$ID2.mpk
     if [ -e $IN1 ]; then
	 if [ -e $IN2 ]; then
	     local out_base=$OUT3/$TARGET/inter-$NUM
	     mkdir -p $OUT

	     echo $INTERSECT \
		  --input1 $IN1 \
		  --input2 $IN2 \
		  --lat0 $LAT0 --lat1 $LAT1 --lon0 $LON0 --lon1 $LON1 \
		  --delta-t $DELTA_T \
		  --tau $TAU \
		  --report $out_base.txt \
		  --t-min $T_MIN \
		  --t-max $T_MAX \
		  --min-overlap $RHO_PH3 \
		  --omega $OMEGA \
		  --output-base $out_base >>$PPC_CMD
	 else
	     msg "Skipping pair $NUM because second input file $IN2 is missing"
	 fi
     else
	 msg "Skipping pair $NUM because first input file $IN1 is missing"
     fi

 done) <$PAIRS

msg "Running per-pixel coincidences"
parallel <$PPC_CMD
