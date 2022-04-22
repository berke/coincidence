#!/bin/zsh

mkdir -p out
DELTA_T=3600 \
  TPI=~/src/cnesch4/python/tpi-iasi.dat \
  TARGET=siberia \
  scripts/run-pixel-coincidences.sh
cat out/inter-??????.txt >out/inter-all.txt
cut -c6- out/inter-all.txt|sort >out/inter-all-sorted.txt
awk 'BEGIN{} { num[$1]+=1 } END{for (k in num) { printf("|| %s || %4d ||\n",k,num[k]) } }' < out/inter-all-sorted.txt|sort >out/inter-all-by-day.txt
awk 'BEGIN{FS="\t"} { m=substr($1,6,2); num[m]+=1 } END{for (k in num) { printf("|| %s || %4d ||\n",k,num[k]) } }' < out/inter-all-sorted.txt|sort >out/inter-all-by-month.txt
