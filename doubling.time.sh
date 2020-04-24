#!/bin/sh

PATTERN="$1"

if [ -z "$PATTERN" ] ; then
	PATTERN='San Diego'
fi

# Determine how many days we average the growth for
DAYRANGE="$2"
if [ -z "$DAYRANGE" ] ; then
	DAYRANGE=7
fi

# Calculate the doubling time for San Diego county

echo Date '     ' Doubling time \(days\)
grep "$PATTERN" data.csv | awk -F, '
{
	v = '$DAYRANGE'; # Get the average growth for the last DAYRANGE days
	n = n + 1;
	cases = $5;
	if(last > 0) {
		growth = cases / last;
		list[n%v] = growth
	} else {
		list[n%v] = 0
	}
	sum = 0;
	for(a=0;a<v;a++) {
		sum += list[a]
	}
	if(v > 0 && log(sum/v) > 0 && cases > 10) {
		printf("%s %f %d\n",$1,log(2)/log(sum/v),cases)
	}
	last = cases
}'
