#!/bin/sh

# Calculate the doubling time for San Diego county

echo Date '     ' Doubling time \(days\)
grep 'San Diego' data.csv | awk -F, '
{
	v = 7; # Get the average growth for the last seven days
	n = n + 1;
	this = $5;
	if(last > 0) {
		growth = this / last;
		list[n%v] = growth
	} else {
		list[n%v] = 0
	}
	sum = 0;
	for(a=0;a<v;a++) {
		sum += list[a]
	}
	if(log(sum/v) > 0 && this>10) {
		print $1 " " log(2)/log(sum/v)
	}
	last = this
}'
