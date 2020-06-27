#!/usr/bin/env python3

# This shows the growth by county on standard output.  It takes the
# JSON in covid-18-byCounty.json on standard input:

# cat covid-19-byCounty.json | ./doubling.time.py3

# The output format is a comma separated list:
# date, state, county, doubling time (days, 7-day average), number of cases

growthDaysToAverage = 14
lookAtDeaths = False

import sys, json
from math import log
from datetime import date
from re import sub
import time

# Gather information about number of cases and growth rate
j = json.loads(sys.stdin.read())

countyGrowth = {}
casesByDate = {}
for state in sorted(j.keys()):
    state = sub(':','_',state)
    for county in sorted(j[state].keys()):
        county = sub(':','_',county)
        last = 0
        averageGrowthArray = []
        arrayIndex = 0
        mostRecentCases = 0
        for day in sorted(j[state][county].keys()):
            day = sub(':','_',day)
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
                casesByDate[day]["ALL:"] = 0
            if(not state in countyGrowth[day]):
                countyGrowth[day][state] = {}
                casesByDate[day][state] = {}
                casesByDate[day][state]["ALL:"] = 0
            casesByDate[day]["ALL:"] += cases
            casesByDate[day][state]["ALL:"] += cases
            if growthDays >= growthDaysToAverage:
                countyGrowth[day][state][county] = averageGrowth
                casesByDate[day][state][county] = cases

# Populate growth for "ALL:" elements
allYesterday = 0
stateYesterday = 0
for day in sorted(casesByDate.keys()):
    if allYesterday > 0:
        countyGrowth[day]["ALL:"] = casesByDate[day]["ALL:"] / allYesterday
    else:
        countyGrowth[day]["ALL:"] = 0 # Infinity, actually
    allYesterday = casesByDate[day]["ALL:"]
    for state in countyGrowth[day]:
        if state == "ALL:":
            continue
        if stateYesterday > 0:
            countyGrowth[day][state]["ALL:"] = (
casesByDate[day][state]["ALL:"] / stateYesterday)
        else:
            countyGrowth[day][state]["ALL:"] = 0
        stateYesterday = casesByDate[day][state]["ALL:"]

for day in countyGrowth:
    for state in countyGrowth[day]:
        if state == "ALL:":
            num = countyGrowth[day][state]
            if(num != 0 and log(num) != 0):
                print (
day + "," + state + ",ALL:," + str(log(2)/log(num)) + "," + 
str(casesByDate[day][state]))
            continue
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


