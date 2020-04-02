#!/usr/bin/awk -f

{
	v = 7; 
	n = n + 1;
	cases = $1;
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
	if(log(sum/v) > 0 && cases > 10) {
		printf("%f %d\n",log(2)/log(sum/v),cases)
	}
	last = cases
}
