#!/bin/bash

COUNTY="$1"
REPO="$2"
if [ -z "$COUNTY" ] ; then
	COUNTY="06073" # San Diego county FIPS code
fi
if [ -z "$REPO" ] ; then
	REPO="https://github.com/nytimes/covid-19-data/"
fi

DIR=$( echo $REPO | cut -f5 -d/ )
if [ ! -e "$DIR" ] ; then
	git clone $REPO > /dev/null 2>&1
fi
cd $DIR
git pull origin master > /dev/null 2>&1
cp us-counties.csv ../data.csv
cd ..

grep $COUNTY data.csv | awk -F, '
    BEGIN{print "Date,Cases,Average Growth"}
    {
    # Calculate raw growth
    if(last){growth = $5 / last}
    last = $5

    # Low pass filter to smooth curve
    if(growth){filter = (filter + growth) / 2}
    growth = filter

    # Convert growth in to percent string
    if(growth>=1){growth = (growth - 1)*100;growth=sprintf("%1f",growth)}
    else{growth="0"}

    print $1 "," $5 "," growth
    }
'
