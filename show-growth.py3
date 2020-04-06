#!/usr/bin/env python3

# This shows the growth by county on standard output.  It takes the
# JSON in covid-18-byCounty.json on standard input:

# cat covid-19-byCounty.json | ./show-growth.py3

# The output format is a comma separated list:
# date, predicted cases, predicted doubling days, number of cases, 
# .... projected cases, county, state
# Here, predicted cases is the number of cases this county was projected to 
# have a week before; projected cases is the number of cases we think this
# county will have in seven days

growthDaysToAverage = 7
casesThreshold = 100
lookAtDeaths = False

import sys, json
from math import log
from datetime import date
import time

# Given a "theDay" in the form "2020-04-05", and the number of days
# to move it (positive in the future, negative in the past), move it
# that many days.  For example, moveIsoDate("2020-04-05",-6) gives
# us "2020-03-31"; moveIsoDate("2020-03-31",2) gives us "2020-04-02"
def moveIsoDate(theDay,days):
    year = int(theDay[0:4])
    month = int(theDay[5:7])
    day = int(theDay[8:10])
    stamp = time.mktime((year, month, day, 0, 0, 0, 0, 0, 0))
    movedStamp = stamp + (86400 * days)
    return str(date.fromtimestamp(movedStamp))

# Gather information about number of cases and growth rate
j = json.loads(sys.stdin.read())

# Get string date for last date in JSON and seven days ago
mostRecent="0000-00-00"
for state in sorted(j.keys()):
    for county in sorted(j[state].keys()):
        for day in sorted(j[state][county].keys()):
            if day > mostRecent:
                mostRecent = day

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
            oneWeekAhead = moveIsoDate(day,7)
            yesterday = moveIsoDate(day,-1)
            if(not day in countyGrowth):
                countyGrowth[day] = {}
                casesByDate[day] = {}
                prediction[oneWeekAhead] = {}
            if(not state in countyGrowth[day]):
                countyGrowth[day][state] = {}
                casesByDate[day][state] = {}
                prediction[oneWeekAhead][state] = {}
            if growthDays >= growthDaysToAverage:
                countyGrowth[day][state][county] = averageGrowth
                try:
                    lastGrowthDelta = growthDelta
                    growthDelta = (averageGrowth /
                            countyGrowth[yesterday][state][county] )
                    growthDelta = (growthDelta * 3 + lastGrowthDelta * 1) / 4
                except:
                    growthDelta = 1
                casesByDate[day][state][county] = cases
                iPredict = cases
                zab = 1
                for zaa in range(7):
                    iPredict = iPredict * averageGrowth * zab
                    zab *= growthDelta
                print(str(growthDelta) + " " + county)
                prediction[oneWeekAhead][state][county] = iPredict

output = {}
lookAt = []
for a in range(14):
    lookAt.append(moveIsoDate(mostRecent, -a))

for lookDay in lookAt:
    if lookDay in countyGrowth:
        for state in countyGrowth[lookDay].keys():
            for county in countyGrowth[lookDay][state].keys():
                thisCases = casesByDate[lookDay][state][county]
                thisGrowth = countyGrowth[lookDay][state][county]
                try:
                    predicted = prediction[lookDay][state][county] 
                except:
                    predicted = -1
                if(thisGrowth > 1):
                    doublingDays = log(2)/log(thisGrowth)
                else:
                    doublingDays = 0 
                try:
                    thisMagicNumber = (prediction[moveIsoDate(lookDay,7
                        )][state][county])
                except:
                    thisMagicNumber = thisCases * (thisGrowth ** 7)
                line = (lookDay + "," + str(predicted) + "," +
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
