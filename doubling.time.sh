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

echo 'Colulmns are (left to right):'
echo '1. Date'
echo '2. Number of cases'
echo '3. Calculated doubling time in days'
echo '4. Actual doubling time in days'
echo '5. New daily cases (compared to yesterday)'
echo '6. New daily cases ('$DAYRANGE'-day average)'

echo 'Date          Cases   Doubling time        New daily cases'
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
	delta = cases - last
	deltalist[n%v] = delta
	deltasum = 0
	for(a=0;a<v;a++) {
		deltasum += deltalist[a]
	}
        if(v > 0 && log(sum/v) > 0 && cases > 10) {
                printf("%s %8d %8.2f %8d %8d %8.2f\n",$1,cases,
				log(2)/log(sum/v),
                                actualDoublingDays,delta,deltasum/v)
        }
        last = cases
}'
