#!/usr/bin/env python3

# This shows the growth by county on standard output.  It takes the
# JSON in covid-18-byCounty.json on standard input:

# cat covid-19-byCounty.json | ./doubling.time.py3

# The output format is a comma separated list:
# date, state, county, doubling time (days, 7-day average), number of cases

growthDaysToAverage = 7
lookAtDeaths = False

import sys, json
from math import log
from datetime import date
import time

# Gather information about number of cases and growth rate
j = json.loads(sys.stdin.read())

countyGrowth = {}
casesByDate = {}
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
            if(not state in countyGrowth[day]):
                countyGrowth[day][state] = {}
                casesByDate[day][state] = {}
            if growthDays >= growthDaysToAverage:
                countyGrowth[day][state][county] = averageGrowth
                casesByDate[day][state][county] = cases

for day in countyGrowth:
    for state in countyGrowth[day]:
        for county in countyGrowth[day][state]:
            num = countyGrowth[day][state][county]
            if(num == 0 or log(num) == 0):
                print (
day + "," + state + "," + county + ",infinity," + 
str(casesByDate[day][state][county]))
            else:
                print (
day + "," + state + "," + county + "," + str(log(2)/log(num)) + "," + 
str(casesByDate[day][state][county]))


