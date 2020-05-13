#!/bin/sh

# This makes an ASCII graph of actual doubling time

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

grep "$PATTERN" data.csv | awk -F, '
{
        v = '$DAYRANGE'; # Get the average growth for the last DAYRANGE days
        n = n + 1
        cases = $5
        deaths = $6
        # Uncomment ithe next line to track deaths
        #cases = deaths

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
        if(hadHalf > 0 && noHalf==0 && cases > 1 && casesHistory[hadHalf]>1) {
                actualDoublingDays = 1 + n - hadHalf
        } else {
                actualDoublingDays = -1
		minGraph = n
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
        if(v > 0 && log(sum/v) > 0) {
                calculatedDoublingDays = log(2)/log(sum/v)
        } else {
                calculatedDoublingDays = 0
        }
        if(actualDoublingDays<22) {
                actualHistory[n] = actualDoublingDays
        } else {
                actualHistory[n] = 22
        }
        last = cases
}
END {
        for(row=22;row>0;row--) {
                printf("| ")
                for(n=minGraph;n<60+minGraph;n++) {
                        if(actualHistory[n] == row) {
                                if(row == 22) {
                                        printf("+")
                                } else {
                                        printf("O")
                                }
                        } else {
                                printf(" ")
                        }
                }
                print ""
        }
        printf("+-")
        for(n=minGraph;n<60+minGraph;n++) {
                printf("-")
        }
        print ""
}'
