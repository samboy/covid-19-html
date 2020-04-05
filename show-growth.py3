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
from datetime import date
import time

j = json.loads(sys.stdin.read())

# Get string date for last date in JSON and seven days ago
mostRecent="0000-00-00"
for state in sorted(j.keys()):
    for county in sorted(j[state].keys()):
        for day in sorted(j[state][county].keys()):
            if day > mostRecent:
                mostRecent = day

year = int(mostRecent[0:4])
month = int(mostRecent[5:7])
day = int(mostRecent[8:10])
stamp = time.mktime((year, month, day, 0, 0, 0, 0, 0, 0))
lastWeek = stamp - (86400 * 7)
lastWeekDay = str(date.fromtimestamp(lastWeek))

# Gather information about number of cases and growth rate
countyGrowth = {}
casesByDate = {}
prediction = {}
for state in sorted(j.keys()):
    for county in sorted(j[state].keys()):
        last = 0
        averageGrowthArray = []
        arrayIndex = 0
        mostRecentCases = 0
        for day in sorted(j[state][county].keys()):
            cases = j[state][county][day]["cases"]
            deaths = j[state][county][day]["deaths"]
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
            if(not day in countyGrowth):
                countyGrowth[day] = {}
                casesByDate[day] = {}
                prediction[day] = {}
            if(not state in countyGrowth[day]):
                countyGrowth[day][state] = {}
                casesByDate[day][state] = {}
                prediction[day][state] = {}
            if growthDays >= 7:
                countyGrowth[day][state][county] = averageGrowth
                casesByDate[day][state][county] = cases
                prediction[day][state][county] = cases * (averageGrowth ** 7)

output = {}
for lookDay in [lastWeekDay, mostRecent]:
    if lookDay in countyGrowth:
        for state in countyGrowth[lookDay].keys():
            for county in countyGrowth[lookDay][state].keys():
                thisCases = casesByDate[lookDay][state][county]
                thisGrowth = countyGrowth[lookDay][state][county]
                if(thisGrowth > 1):
                    doublingDays = log(2)/log(thisGrowth)
                else:
                    doublingDays = 0 
                thisMagicNumber = thisCases * (thisGrowth ** 7)
                line = (lookDay + "," + 
                    str(doublingDays) + "," + str(thisCases) +
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
