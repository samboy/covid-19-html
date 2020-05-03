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

echo 'Date          Cases   Doubling time(days): Calculated and actual'
grep "$PATTERN" data.csv | awk -F, '
{
        v = '$DAYRANGE'; # Get the average growth for the last DAYRANGE days
        n = n + 1
        cases = $5

        # Calculate the actual doubling time, i.e. the last day we had
        # fewer than half the cases
        casesHistory[n] = cases
        noHalf = 0
        while(casesHistory[hadHalf] < cases / 2) {
                hadHalf++
                if(hadHalf > n) {
                        noHalf = 1
                        hadHalf = 0
                        break
                }
        }
        if(hadHalf > 0 && noHalf == 0) {
                actualDoublingDays = 1 + n - hadHalf
        } else {
                actualDoublingDays = -1
        }

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
                printf("%s %8d %8.2f %8d\n",$1,cases,log(2)/log(sum/v),
                                actualDoublingDays)
        }
        last = cases
}'
