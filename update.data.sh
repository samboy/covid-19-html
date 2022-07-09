#!/bin/sh

# This updates the data.csv file.  This file can be run until the
# end of 2022; come 2023, this will need to be updated as needed

REPO="$1"
if [ -z "$REPO" ] ; then
        REPO="https://github.com/nytimes/covid-19-data/"
fi

DIR=$( echo $REPO | cut -f5 -d/ )
if [ ! -e "$DIR" ] ; then
        git clone $REPO > /dev/null 2>&1
fi
cd $DIR
git pull > /dev/null 2>&1
cd ..

cat covid-19-data/us-counties.csv covid-19-data/us-counties-2022.csv |\
	grep -v 'fips' | sort -u > foo
echo 'date,county,state,fips,cases,deaths' > data.csv
cat foo >> data.csv
rm foo
