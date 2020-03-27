#!/bin/bash

REPO="https://github.com/nytimes/covid-19-data/"
COUNTY="06073" # San Diego county FIPS code

git clone $REPO
cp covid-19-data/us-counties.csv data.csv
grep $COUNTY data.csv | awk -F, '
    BEGIN{print "<table><tr><th>Date</th><th>Cases</th><th>Growth</th></tr>"}
    {
    if(last){growth = $5 / last}
    if(growth){growth = (growth - 1)*100;growth=sprintf("%1f%%",growth)}
    last = $5
    print "<tr>" $1 "</tr><tr>" $5 "</tr><tr>" growth "</tr>"
    }
    END {print "</table>"}
'
