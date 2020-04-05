#!/usr/bin/env python3

# This shows the growth by county on standard output.  It takes the
# JSON in covid-18-byCounty.json on standard input:

# cat covid-19-byCounty.json | ./show-growth.py3

# The output format is a comma separated list:
# doubling days, number of cases (most recent), projected cases, county, state

growthDaysToAverage = 7
casesThreshold = 1000
lookAtDeaths = False

import sys, json
from math import log

j = json.loads(sys.stdin.read())
countyGrowth = {}
casesMostRecent = {}
for state in sorted(j.keys()):
    for county in sorted(j[state].keys()):
        last = 0
        averageGrowthArray = []
        arrayIndex = 0
        mostRecentCases = 0
        for date in sorted(j[state][county].keys()):
            cases = j[state][county][date]["cases"]
            deaths = j[state][county][date]["deaths"]
            if lookAtDeaths:
                cases = deaths 
            if(last > 0):
                growthToday = cases / last
            else:
                growthToday = 0
            if(len(averageGrowthArray) <= (arrayIndex % growthDaysToAverage)):
                averageGrowthArray.append(0)
            averageGrowthArray[arrayIndex % growthDaysToAverage] = growthToday
            arrayIndex = arrayIndex + 1
            last = cases
            mostRecentCases = cases

        # Figure out the n-day average growth for this county
        totalGrowth = 0
        growthDays = 0
        for singleGrowth in averageGrowthArray:
            growthDays = growthDays + 1
            totalGrowth = totalGrowth + singleGrowth
        if growthDays > 0:
            averageGrowth = totalGrowth / growthDays
        else:
            averageGrowth = 0
        if(not state in countyGrowth):
            countyGrowth[state] = {}
            casesMostRecent[state] = {}
        if growthDays >= 7:
            countyGrowth[state][county] = averageGrowth
            casesMostRecent[state][county] = mostRecentCases

output = {}
for state in countyGrowth.keys():
    for county in countyGrowth[state].keys():
        thisCases = casesMostRecent[state][county]
        thisGrowth = countyGrowth[state][county]
        if(thisGrowth > 1):
            doublingDays = log(2)/log(thisGrowth)
        else:
            doublingDays = 0 
        thisMagicNumber = thisCases * (thisGrowth ** 14)
        line = (str(doublingDays) + "," + str(thisCases) +
                "," + str(thisMagicNumber) + "," + county + "," + 
                state) 
        if thisCases > casesThreshold:
            if thisMagicNumber in output:
                if thisCases in output[thisMagicNumber]:
                    output[thisMagicNumber][thisCases].append(line)
                else:
                    output[thisMagicNumber][thisCases] = [line]
            else:
                output[thisMagicNumber] = {}
                output[thisMagicNumber][thisCases] = [line]

for thisMagicNumber in sorted(output.keys()):
    for thisCases in sorted(output[thisMagicNumber].keys()):
        for line in sorted(output[thisMagicNumber][thisCases]):
            print(line)
