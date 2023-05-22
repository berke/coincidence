#!/bin/zsh

OUT=${OUT:-out}
cat $OUT/inter-??????.txt >$OUT/inter-all.txt
cut -c6- $OUT/inter-all.txt|sort >$OUT/inter-all-sorted.txt
awk 'BEGIN{} { num[$1]+=1 } END{for (k in num) { printf("|| %s || %4d ||\n",k,num[k]) } }' < $OUT/inter-all-sorted.txt|sort >$OUT/inter-all-by-day.txt
awk 'BEGIN{FS="\t"} { m=substr($1,6,2); num[m]+=1 } END{for (k in num) { printf("|| %s || %4d ||\n",k,num[k]) } }' < $OUT/inter-all-sorted.txt|sort >$OUT/inter-all-by-month.txt
