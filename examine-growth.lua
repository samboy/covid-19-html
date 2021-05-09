#!/usr/bin/env lua-5.1

-- This will work with Lua 5.4 as well as LuaJIT 2.1.0-beta3 (Lua 5.1 
-- compatible), and pretty much anything in between

require("LUAstuff")
require("stateNameAbbr")
require("governors")
require("USmap")

---------------------------------------------------------------------------
-- Human name for county,state
function humanCounty(i)
  out, rest = string.gsub(i,",",", ")
  return out
end

---------------------------------------------------------------------------
-- Process the totals we have to get growth rates and other calculated data 
-- Input: A table which has a lot of data about COVID-19 cases and
-- deaths; useDeaths, a boolean, that, if true, means we process deaths,
-- not cases
-- Output: The maximum number of cases per 100,000 people we saw
-- Side effects: We add a lot of data to ourCOVIDtable
function processCOVIDtable(ourCOVIDtable, useDeaths)
  local maxCasesPer100k = 0
  for place, here in sPairs(ourCOVIDtable) do
    for date, today in sPairs(here.date) do
      here.mostRecent = today 
      here.mostRecentDate = date
      here.n = here.n + 1

      -- Calculate actual doubling time (when we had half the cases compared
      -- to a given day)
      if useDeaths then
        today.cases = today.deaths
      end
      here.noHalf = 0
      here.casesHistory[here.n] = today.cases
      while here.casesHistory[here.hadHalf] and 
          here.casesHistory[here.hadHalf] < (today.cases / 2) do
        here.hadHalf = here.hadHalf + 1
        if here.hadHalf > here.n then
          here.noHalf = 1
          here.hadHalf = 1
          break
        end
      end
      if here.hadHalf > 1 and here.noHalf == 0 then
        today.actualDoublingDays = 1 + here.n - here.hadHalf
      else
        today.actualDoublingDays = 0
      end

      -- Calculate an average growth over a range of days
      today.growth = 0
      if here.last > 0 then
        today.growth = today.cases / here.last
      else
        today.growth = 0
      end
      here.rollingAverage[here.n % g_dayrange] = today.growth
      today.sum = 0
      for a = 0, g_dayrange do
        if here.rollingAverage[a] then
          today.sum = today.sum + here.rollingAverage[a]
        end
      end
      today.averageGrowth = today.sum / g_dayrange

      -- Calculate the yesterday and average daily increase in cases
      today.delta = today.cases - here.last
      here.deltaList[here.n % g_dayrange] = today.delta
      here.delta14List[here.n % 14] = today.delta
      today.deltaSum = 0
      for a = 0, g_dayrange do
        if here.deltaList[a] then
          today.deltaSum = today.deltaSum + here.deltaList[a]
        end 
      end
      today.delta14Sum = 0
      for a = 0, 13 do
        if here.delta14List[a] then
          today.delta14Sum = today.delta14Sum + here.delta14List[a]
        end
      end
      if g_dayrange > 0 then
        today.deltaAverage = today.deltaSum / g_dayrange
      end

      -- Last is yesterday's case count
      here.last = today.cases

      -- Calculate the projected doubling time
      today.calculatedDoublingTime = 0
      if g_dayrange > 0 and math.log(today.averageGrowth) > 0 then
        today.calculatedDoublingTime = 
            math.log(2) / math.log(today.averageGrowth)
      end

      -- Cases per 100,000 people
      if here.pop and here.pop > 0 then
        today.casesPer100k = (today.cases / here.pop) * 100000
        today.delta14capita = (today.delta14Sum / here.pop) * 100000
        if today.casesPer100k > maxCasesPer100k then
          maxCasesPer100k = today.casesPer100k
        end
      end

    end
  end
  return maxCasesPer100k
end

-------------------------------- process args --------------------------------

if #arg == 0 then
  print [=[Basic usage:

Step one is to grab the data from The New York Times:

	git clone https://github.com/nytimes/covid-19-data/
	cp covid-19-data/us-counties.csv data.csv

Then we can make a SVG map showing growth, where green is low growth
and red is high growth:

	lua examine-growth.lua svg > map.svg

We can also make a bunch of GNUplot graph commands in one sweep; this
puts a bunch of files in the GNUplot directory:

	lua examine-growth.lua gnuplot

To see some more examples of usage:

	lua examine-growth.lua --examples

To see a full reference manual:

	lua examine-growth.lua --help
  ]=]
  os.exit(0)
end

if arg[1] == '--help' then
  print [=[
The file "data.csv" needs to be fetched from the NYT to run this program.

Usage:

	examine-growth [action] [args]

Action can be either "--help" to show this message, "--examples" to
show examples of this program being used, "cases" to show the cases
for a given location by day, "csv" to show the cases in CSV format
(for spreadsheets), or "svg" to output a SVG map image on standard output.

If "action" is "cases" or "csv", the first optional argument is the
county or state name we print data for.  Use County,State to specify
a given county.  Should we have both a state and county with a name,
we use the state name.  Avoid naming just a county without a state.
Use "USA" to look at overall national numbers.  Default is "San Diego".

If action is "svg", in the generated map green means good, red means
bad.  The first optional argument is what to visualize.  Can be one of
"averageGrowth" (how much growth have we seen over the last days),
"actualDoublingDays", "calculatedDoublingTime", "casesPer100k",
"casesPer100kLog", or "herdImmunityCalc" (how long it would take for 2.5%
of population percent to have COVID-19).  Default is "averageGrowth".

For "cases", "csv", or "svg", subsequent arguments are: 

2. Day range: How many days do we average some numbers over. Default: 7
3. Do deaths: If this is "1", process deaths, not cases. Default: 0

If action is hotSpots or hotSpots2, find possible "hot spots".
  ]=]
  os.exit(0)
end
if arg[1] == "--examples" then
  print [=[Examples of usage:

Step one is to grab the data from The New York Times:

	git clone https://github.com/nytimes/covid-19-data/
	cp covid-19-data/us-counties.csv data.csv

Once we have the data.csv file, we can make a SVG map:

	lua examine-growth.lua svg > map.svg

We can also make a CSV file for, say Arizona, to import in to a spreadsheet:

	lua examine-growth.lua csv Arizona > COVID-19.csv

To look at growth in just Miami-Dade county in a CSV file:

	lua examine-growth.lua csv Miami.Dade,Florida > COVID-19.CSV

To see how much of a problem we have in Houston, Texas:

	lua examine-growth.lua csv Harris,Texas > COVID-19.CSV

(Houston is in Harris county)

Make a SVG map of the number of cases per capita:

	lua example-growth.lua svg casesPer100k > map.svg

To see a reference manual, type in lua examine-growth.lua --help
  ]=]
  os.exit(0)
end

g_dayrange = 7
if arg[1] == "cases" or arg[1] == "csv" then
  g_outputFormat = arg[1]
  g_search = arg[2] or "San Diego"
  g_dayrange = tonumber(arg[3]) or 7
  g_doDeaths = arg[4] or false
  -- Let's be compatible with the old AWK script; 0 being false is
  -- the case in pretty much anything besides Lua
  if arg[4] and tonumber(arg[4]) == 0 then g_doDeaths = false end
end
if arg[1] == "svg" then
  g_field = arg[2] or "averageGrowth"
  if g_field ~= "averageGrowth" and 
     g_field ~= "actualDoublingDays" and
     g_field ~= "calculatedDoublingTime" and
     g_field ~= "casesPer100k" and
     g_field ~= "casesPer100kLog" and
     g_field ~= "herdImmunityCalc" then
    print("Invalid field to view for SVG map")
    os.exit(1)
  end
  g_dayrange = tonumber(arg[3]) or 7
  g_doDeaths = arg[4] or false
  if arg[4] and tonumber(arg[4]) == 0 then g_doDeaths = false end
end

-------------------------------------------------------------------------
-- Read by-county population data
io.input("co-est2019-annres.csv")
line = ""
pop = {}
USpop = 0
while line do
  line = io.read()
  if not line then break end
  fields = rCharSplit(line,",")
  county = fields[1]
  state = fields[2]  
  place = fields[1] .. "," .. fields[2]
  population = tonumber(fields[3])
  pop[place] = population
  if not pop[state] then pop[state] = 0 end
  pop[state] = pop[state] + population
  USpop = USpop + population
end
io.close()
-- Numbers obtained from the Wikipedia 2020-07-03
if not pop["Alaska"] then pop["Alaska"]=710249 end
if not pop["District of Columbia"] then pop["District of Columbia"]=705749 end
if not pop["Louisiana"] then pop["Louisiana"]=4648794 end
  
io.input("data.csv")
covidData = {}

-- Initialize a given location's data
function initPlaceData() 
  out = { casesHistory = {}, rollingAverage = {}, deltaList = {},
          delta14List = {},
	  n = 0, hadHalf = 1, last = 0, date = {} }
  return out;
end

-- Read the CSV file and get basic cases and growth from it
line = io.read() -- Discard first line (fields)
while line do
  line = io.read()
  if not line then break end
  fields = rCharSplit(line,",")
  date = fields[1]
  place = fields[2] .. "," .. fields[3]
  if not covidData[place] then covidData[place] = initPlaceData() end
  here = covidData[place]
  here.county = fields[2]
  here.state = fields[3]
  here.pop = pop[place]
  here.date[date] = {}
  today = here.date[date]
  
  -- Get information from the comma separated line
  today.cases = tonumber(fields[5]) or 0
  today.deaths = tonumber(fields[6]) or 0
end

----------------------------------------------------------------------------
-- The attangement of the data created above is as follows:
-- covidData is a table.  Each key is a string.  The string
-- is a place name, like "San Diego,California" or 
-- "Miami-Dade,Florida".  Each value is itself a table
-- That "place" table has the following fields:
-- casesHistory: Used to determine how long ago we had 1/2 of the cases
--               (accounting field for calculations)
-- rollingAverage: Used to determine the (usually) 7-day average growth
-- deltaList: Used to determine the 7-day average of new cases
--
-- delta14List: Used to determine the 14-day amount of new cases per 100k
-- (California uses this number for their COVID-19 calculations)
--
-- n: Used with rollingAverage and deltaList to know which index to fetch
--    on a given day (another accounting field for calculations)
-- hadHalf: When we last saw 1/2 the cases (accounting field)
-- last: Previous day's cases (or deaths) (accounting field)
-- date: This is the main field we need to look at once things
--       are calculated.  This is a table where the keys are ISO dates
--       (e.g. "2020-07-12" as a string); each element of the date
--       table is a table which starts off with two values: "cases" and
--       "deaths" (the total cumulative cases and deaths for a given day
--       at a given place)
-- state: This is the name of the state a given "county" place is in
--       (e.g. for "San Diego,California", state is "California")
--       places which are not counties will not have this field.
-- Note that we will add a bunch more data to this table later, but this
-- is how things start off.

----------------------------------------------------------------------------
-- Add up numbers in a state to get a by-state total.
-- Also generates nation-wide total, as well as a combined total for all
-- red states as well as a total for blue states.
--
-- red/blue here is the affiliation of the Governor (Democrat: blue
-- Republican: red).  For this dataset, we consider Puerto Rico's 
-- governor to be "red", even though Garced was Democrat until 2019.

state = {}
USA = initPlaceData()
stateByGov = {}
for place, here in sPairs(covidData) do
  if not state[here.state] then 
    state[here.state] = initPlaceData() 
    state[here.state]["countyList"] = {} 
  end

  local stateColor = "none"
  if here.state and stateNameAbbr[here.state] and
     stateGovernor[stateNameAbbr[here.state]] then
    stateColor = tostring(stateGovernor[stateNameAbbr[here.state]])
  end

  -- Yes, all states now have a color properly assigned to them
  -- But, should that ever change....
  if stateColor ~= "red" and stateColor ~= "blue" then
    print("No color for state " .. here.state .. "\n")
    os.exit(1)
  end

  if not stateByGov[stateColor] then
    stateByGov[stateColor] = initPlaceData()
  end

  table.insert(state[here.state]["countyList"], place)
  for date, today in sPairs(here.date) do
    if not state[here.state].date[date] then 
      state[here.state].date[date] = {} 
    end
    if not USA.date[date] then USA.date[date] = {} end
    if not stateByGov[stateColor].date[date] then 
      stateByGov[stateColor].date[date] = {}
    end
    if not state[here.state].date[date].cases then
      state[here.state].date[date].cases = 0
    end
    if not USA.date[date].cases then USA.date[date].cases = 0 end
    if not stateByGov[stateColor].date[date].cases then 
      stateByGov[stateColor].date[date].cases = 0 
    end
    if not state[here.state].date[date].deaths then
      state[here.state].date[date].deaths = 0
    end
    if not USA.date[date].deaths then USA.date[date].deaths = 0 end
    if not stateByGov[stateColor].date[date].deaths then 
      stateByGov[stateColor].date[date].deaths = 0 
    end
    state[here.state].date[date].cases = state[here.state].date[date].cases +
        today.cases
    state[here.state].date[date].deaths = state[here.state].date[date].deaths +
        today.deaths
    USA.date[date].cases = USA.date[date].cases + today.cases
    USA.date[date].deaths = USA.date[date].deaths + today.deaths
    stateByGov[stateColor].date[date].cases =
        stateByGov[stateColor].date[date].cases + today.cases
    stateByGov[stateColor].date[date].deaths =
        stateByGov[stateColor].date[date].deaths + today.deaths
  end
end
for state, here in sPairs(state) do
   covidData[state] = here
   covidData[state].pop = pop[state]
end
covidData["USA"] = USA
covidData["USA"].pop = USpop

-- Add fields for red states and blue states
covidData["redStates"] = stateByGov["red"]
covidData["blueStates"] = stateByGov["blue"]

-----------------------------------------------------------------------------
-- OK, back to that covidData table.  We have filled it out some more.  
-- We have, at the top level, added a bunch of places: There are now 55
-- states and territories added to the table ("California", "Florida",
-- etc.) which have the total cases and deaths each day for those places.  
-- In -- addition we have the special "USA" (total cases and deaths per 
-- day) field, as well as "redStates" (states with a Republican governor)
-- and "blueStates" (Democrat governor)
-- The structure is the same:
-- place.date.2020-XX-XX.cases and place.date.2020-XX-XX.deaths, where
-- "place" is "California", "San Diego,California", "USA", etc. and XX-XX
-- is a different element for each day.  Cases and deaths are cumulative.
-- Now, let's add a bunch of information to those tables:
covidCases = tableCopyD(covidData)
covidDeaths = tableCopyD(covidData)
maxCasesPer100k = processCOVIDtable(covidCases, false)
processCOVIDtable(covidDeaths, true)
-- And now we have covidCases and covidDeaths which have taken the cases 
-- and deaths, and have added a bunch of other fields, including:
-- place.date.2020-XX-XX.actualDoublingDays: How many days did we have
-- 	half of today's cases/deaths
-- place.date.2020-XX-XX.averageGrowth: (Usually) 7-day average growth,
-- 	as an absolute number (e.g. 1% growth is 1.01)
-- place.date.2020-XX-XX.deltaAverage: 7-day increase in the number of cases
-- place.date.2020-XX-XX.calculatedDoublingTime: Based on average growth,
--      how many days would it take for cases to double.
-- place.date.2020-XX-XX.casesPer100k: How many cases per 100,000 people.
--      This information is not always available (Population data is
--      incomplete)
-- (place is a name like "San Diego,California" or "USA"; 2020-XX-XX is
--  a date and we have all the above information for each day in our table)
-- The table "covidCases" calculated all the above for cases; the table
-- "covidDeaths" calculates all of the above for deaths.  Note that, for
-- both tables place.date.2020-XX-XX.cases is always cases, and
-- place.date.2020-XX-XX.deaths is always deaths.
-- We also have a place.mostRecent, which is a pointer (more like "hard
-- link", since Lua tables are always pointers) to the most
-- recent place.date.2020-XX-XX table.  place.mostRecentDate is a
-- string with the most recent "2020-XX-XX" date (yes, one *could*
-- use place.date[place.mostRecentDate] to get at the most recent day,
-- but mostRecent is a handy shortcut).

if g_doDeaths then 
  all = covidDeaths
else
  all = covidCases
end

for place, here in sPairs(covidCases) do
  for date, today in sPairs(here.date) do
    -- Estimate when we will have "Herd immunity".  Here, "Herd immunity"
    -- is how long, based on estimated doubling time, it would take
    -- for  of the population to have a COVID-19 case (we presume the
    -- other 90% are asymptomatic) 
    if here.pop and math.log(today.averageGrowth) > 0 and today.cases > 0 then
      today.herdImmunityCalc = math.log((here.pop *
	  (maxCasesPer100k / 100000)) / today.cases) /
          math.log(today.averageGrowth)
    end

  end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- At this point, we have built up the data tables.  We now can extract 
-- that data to make CSV output, tabular output, hot spot analysis, or
-- even an entire website to browse some of the data.
----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- Where are the hot spots
heat = {}
byHeat = {}
n = 1
for place, here in pairs(all) do
  if(here.pop) then
    -- Fuzzy heuristic: 7-day average growth, reduce for small populations
    heat[place] = here.mostRecent.averageGrowth;
    if here.mostRecent.cases < 1000 then
      heat[place] = heat[place] * (here.mostRecent.cases / 1000)
    end

    byHeat[n] = place
    n = n + 1
  end
end
table.sort(byHeat, function(y,z) 
	return heat[y] < heat[z] end)

function showHotSpots(heat, byHeat) 
  for a = 1, #byHeat do
    if #byHeat - a < 20 then
      print(byHeat[a],heat[byHeat[a]])
    end
  end
end

if arg[1] == 'hotSpots' then
  showHotSpots(heat, byHeat)
  os.exit(0)
end

if arg[1] == 'hotSpots2' then
  local byCases = {}
  local bySorter = {}
  local b = 1
  for place, here in pairs(all) do
    if(here.pop) then
      bySorter[b] = place
      b = b + 1
      byCases[place] = here.mostRecent.casesPer100k
    end
  end
  table.sort(bySorter, function(y,z) return 
    tonumber(byCases[y]) < tonumber(byCases[z]) 
  end)
  for a = 1, #bySorter do
    if #bySorter - a < 30 then
      print(bySorter[a], byCases[bySorter[a]])
    end
  end
end

-- Header string for tabulated output
function makeHeaderString(outputFormat)
  if outputFormat == "csv" then return
"Date,Doubling time (calculated days),Doubling time (actual days),Cases," ..
"Growth percentage"
  else return
    "Date          Cases   Doubling time        New daily cases"
  end
end
    
-- Make Output string once we have the data to output
function makeString(outputFormat,
        date, cases,calculatedDoublingTime,actualDoublingDays,
        delta, deltaAverage, casesPer100k, herdImmunityCalc,
        averageGrowth, delta14capita)
  if outputFormat == "csv" then
    return string.format("%s,%f,%d,%d,%.2f,%.2f,%.2f,%.2f",date, 
      calculatedDoublingTime,
      actualDoublingDays, cases, casesPer100k, herdImmunityCalc,
      (averageGrowth - 1) * 100, delta14capita or -1)
  else
    return string.format("%s %8d %8.2f %8d %8d %8.2f",date, cases,
      calculatedDoublingTime, actualDoublingDays,
      delta, deltaAverage)
  end
end

-------------------- cases/csv (by County tabulation) --------------------
if arg[1] == 'cases' or arg[1] == 'csv' then
  local here = nil

  -- Look for state with search name
  for place, _ in sPairs(state) do
    if string.match(place, g_search) then
      here = all[place]
      break
    end
  end

  -- Look for county or county,state with search name
  if not here then
    for place, details in sPairs(all) do
      if string.match(place, g_search) then
        here = details
        break
      end
    end
  end

  if not here then
    print("Could not find place " .. g_search)
    os.exit(1)
  end

  print(makeHeaderString(g_outputFormat))
  for date, data in sPairs(here.date) do
    line = makeString(g_outputFormat,
                      date, data.cases, data.calculatedDoublingTime,
                      data.actualDoublingDays, data.delta, 
                      data.deltaAverage, data.casesPer100k, 
                      data.herdImmunityCalc or -1,
                      data.averageGrowth,
                      data.delta14capita or -1)
    print(line)
  end
  os.exit(0)
end

-------------------- make a map of a single datapoint --------------------
-- Input: The database we get data from, the name of the field we use
-- to make the map, the maximum (red) value used on the map (optional)

function makeSVG(covidDataTable, field, useMax, useMin)
  if not field then field = g_field end
  if not field then field = "averageGrowth" end
  local max = 0
  local min = 100000
  local doLog = false
  if field == "casesPer100kLog" then 
    doLog = true 
    field = "casesPer100k"
  end
  -- Find "max" so we have 0 <-> 1 gradient
  if not useMax then
    for state, sAbbr in sPairs(stateNameAbbr) do
      if covidDataTable and covidDataTable[state] and 
         covidDataTable[state]["mostRecent"] and 
         covidDataTable[state]["mostRecent"][field] then
        local t = covidDataTable[state]["mostRecent"][field]
        if doLog then t = math.log(t) / math.log(10) end -- Common log
        -- Only use states visible on map to determine red/green balance
        if sAbbr ~= "VI" and sAbbr ~= "MP" and sAbbr ~= "GU" and
           sAbbr ~= "PR" then
          if t > max then max = t end
          if t < min then min = t end
        end
      end
    end
  else
    if not useMin then min = 0 else min = useMin end
    max = useMax
  end
  -- Make a string with a color for each state
  local repl = ""
  for state, sAbbr in sPairs(stateNameAbbr) do
    if covidDataTable and covidDataTable[state] and 
       covidDataTable[state]["mostRecent"] and
       covidDataTable[state]["mostRecent"][field] then
      local t = covidDataTable[state]["mostRecent"][field]
      if doLog then t = math.log(t) / math.log(10) end -- Common log
      local u
      if t then
        u = (tonumber(t) - min) / (max - min)
      else
        u = 0
      end 
      if u < 0 then u = 0 end
      if u > 1 then u = 1 end
      if g_field == "calculatedDoublingTime" or 
          g_field == "herdImmunityCalc" or
          g_field == "actualDoublingDays" then
        -- color = calcColor(0x80, 0x00, 0x00, 0x00, 0x80, 0x80, u)
        color = calcColor(0xd2, 0x26, 0x32, 0x0b, 0xff, 0x20, u)
      else
        -- color = calcColor(0x00, 0x80, 0x80, 0x80, 0x00, 0x00, u)
        color = calcColor(0x0b, 0xff, 0x20, 0xd2, 0x26, 0x32, u)
      end
      repl = repl .. "#" .. sAbbr .. "{fill: #" .. color .. ";}" ..
             " <!-- " .. tostring(t) .. "-->\n"
    end
  end
  repl = repl .. "<!-- MIN: " .. tostring(min) .. ", MAX: " 
         .. tostring(max) .. "-->"
  local out = string.gsub(USmapSVG,'<!..COLORS..>',repl)
  return out
end

if arg[1] == "svg" then
  print(makeSVG(all))
  os.exit(0)
end

--------------------------------------------------------------------------
-- This makes an array (table where the keys are 1,2,3,4,5,...) where
-- the values are a stat for the table we are looking at.  This is 
-- useful for "Top states for X" or "Top counties for X" lists
-- Input: The Covid case database and field we want to look at;
-- 	if statesOnly is set, we only make a state level list
-- Output: A sorter table
function makeSortableStat(database, field, statesOnly)
  local out = {}
  local lastDate = ""
  for place, here in sPairs(database) do
    if here.mostRecentDate and here.mostRecentDate > lastDate then
      lastDate = here.mostRecentDate
    end
    if (not statesOnly) or state[place] then
      if here.mostRecent and here.mostRecent[field] then
        out[place] = here.mostRecent[field]
      end
    end
  end
  return out, lastDate
end

--------------------------------------------------------------------------
-- Correct place name so it can be a filename
-- This removes quotes, accents, and other potential problems
function filenameCorrect(name) 
  -- The reason why we don’t have accents in filenames is because Cygwin,
  -- when interfacing with native Windows programs, does conversions
  -- between UTF-8 to and ISO 8859-1 charsets, so we need to avoid 
  -- accents to not have issues (gnuplot handles accents just fine
  -- as long as the locale is correctly set up)
  local out = string.gsub(name,"'","-") -- ' is bad mojo in filenames
  out = string.gsub(out,"ñ","ny") -- not "n" because of ¡Feliz ano nuevo!
  out = string.gsub(out,"ö","o") -- Spelled "Coos" in CSV, but just in case
  return out
end

--------------------------------------------------------------------------
-- This makes a HTML list of the top N places for a given stat
-- Input: database (to see if we want to look at case stat data or death
-- stat data), Stat, what to call stat in list, statesOnly (only
-- list states if true, size of list
-- Example field names:
-- - actualDoublingDays
-- - calculatedDoublingTime
-- - casesPer100k (not available everywhere)
-- - averageGrowth
-- - cases
-- - deaths
-- - deltaAverage (7-day average increase in cases)
function makeStatHTML(database, field, fieldHumanName, statesOnly,
	listSize, format, isPercentage, itemPrefix, filePart, itemsEndStr)
  if not fieldHumanName then fieldHumanName = field end
  if not listSize then listSize = 100 end
  if not format then format = "%.2f" end
  if not itemPrefix then itemPrefix = "" end
  if not filePart then filePart = "" end
  local iex = 0
  local out = ""
  local lastDate = ""
  statFieldTable, lastDate = makeSortableStat(database, field, statesOnly)
  for place, value in sPairs(statFieldTable, sortedByRevValue) do
    local tValue = value
    if isPercentage then tValue = (value - 1) * 100 end
    local formatString = humanNumber(tValue,",",format)
    if not string.match(place, 'Unknown') then
      out = out .. itemPrefix .. '<a href="' .. 
        filenameCorrect(place) .. filePart .. '.html">' ..
        place .. "</a>" .. ' ' .. fieldHumanName .. ': ' .. 
        formatString .. "<br>\n"
      iex = iex + 1
      if(iex > listSize) then
        return out
      end
    end
  end
  if itemsEndStr then
    out = out .. itemsEndStr
  end
  if lastDate and lastDate ~= "" then
    out = out .. "List current as of " .. lastDate
  end
  return out
end

----------------------------------------------------------------------------
-- Show a string with copyright information for the page
function showCopyright()
   return [=[
The data comes from <a
href=https://github.com/nytimes/covid-19-data/>The New York
Times</a> and the code to generate these pages is open source and <a
href=https://github.com/samboy/covid-19-html/>available on GitHub</a>.
The number of actual COVID-19 cases and deaths are almost certainly higher
than these figures.
]=] end

----------------------------------------------------------------------------
-- Show a string with CSS style information for the page
function pageStyle()
  return [=[
<style>
@media screen and (min-width: 641px) {
        .page { width: 640px; margin-left: auto; margin-right: auto;
                font-size: 18px; }
}
body { font-family: Arial, sans-serif; 
       overflow-y: scroll; }
a {
        color: #258723;
	background: transparent;
	text-decoration: none;
}	
a:hover {
	text-decoration: underline;
}
h1 { font-weight: bold; }
h2 { font-weight: bold; }
</style>
]=] end

function buttonBarStyle() 
  return [=[<style>
#db {margin-top: 7px;}
.x {display:none;}
.bb {background: black;color: white;border: 2px solid black;font-size: 21px;
     padding: 4px; border-left: 2px solid black;border-right: 2px solid black;
     margin-right: 0px; }
.wb {background: white;color: black;border: 2px solid black;font-size: 21px;
     padding: 4px; border-left: 0px;border-right: 2px solid black; 
     }
.wb a {color: black; padding: 4px; }
</style>
]=] end

function buttonBarToplevel()
  return "<div id=db><span class=bb>Go to:</span>" ..
         "<span class=x> </span>" ..
         "<span class=wb><a href=USA.html>COVID-19 growth</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=USA-deaths.html>Deaths</a></span>" ..
         "</div><p>\n" 
end

function buttonBarSiteMap()
  return "<div id=db><span class=bb>Go to:</span>" ..
         "<span class=x> </span>" ..
         "<span class=wb><a href=index.html>Top</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=SiteMap.html>Site map</a></span>" ..
         "</div><p>\n" 
end

function buttonBarUSACases()
  return "<div id=db><span class=bb>Go to:</span>" ..
         "<span class=x> </span>" ..
         "<span class=wb><a href=USA.html#StateList>States</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=index.html>Top</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=SiteMap.html>Site map</a></span>" ..
         "</div><p>\n" 
end

function buttonBarStateCases()
  return "<div id=db><span class=bb>Go to:</span>" ..
         "<span class=x> </span>" ..
         "<span class=wb><a href=#CountyList>Counties</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=index.html>Top</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=SiteMap.html>Site map</a></span>" ..
         "</div><p>\n" 
end

function buttonBarStateDeaths()
  return "<div id=db><span class=bb>Go to:</span>" ..
         "<span class=x> </span>" ..
         "<span class=wb><a href=USA-deaths.html>USA</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=index.html>Top</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=SiteMap.html>Site map</a></span>" ..
         "</div><p>\n" 
end

function buttonBarUSADeaths()
  return "<div id=db><span class=bb>Go to:</span>" ..
         "<span class=x> </span>" ..
         "<span class=wb><a href=#StateList>States</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=index.html>Top</a></span>" ..
         "<span class=x> - </span>" ..
         "<span class=wb><a href=SiteMap.html>Site map</a></span>" ..
         "</div><p>\n" 
end

function writePageHeader(o, whichBar)
  if not whichBar then whichBar = buttonBarSiteMap end
  -- UTF-8 header
  o:write('<meta http-equiv="Content-Type" ')
  o:write('content="text/html; charset=utf-8">' .. "\n")

  -- Yes, the page works on cell phones.  Also, styling.
  o:write([=[<meta name="viewport"
content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=0"
>
</head>]=])
  o:write(pageStyle())
  o:write(buttonBarStyle())
  o:write("<body>\n<div class=page>\n")
  o:write(whichBar())
end

--------------------------------------------------------------------------
-- This makes a single webpage for the website generator.  It generates
-- 1. The CSV file gnuplot will read to make the PNG file
-- 2. The .gnuplot file with GNUplot directions on how to make the PNG
-- 3. The .html file which shows and describes the GNUplot PNG file 
-- Input: place: Name of the place we make a webpage for
-- (e.g. "San Diego,California" or "Florida")
-- here: A pointer to the data in CovidCases for this datapoint
-- growthByCounty: An updated tally of county growth
-- stateHTMLlist: A HTML file listing all states
-- dir: The location we place the generated files
-- isDeath: If true, we are looking at mortality stats
-- Output: updated growthByCounty
-- Side effects: A .gnuplot, .csv, and .html file are generated
function makeAPage(place, here, growthByCounty, stateHTMLlist, dir, isDeath,
	gFileHandle)
  local fontnameSize = 'Arial,12'
  -- Lua handles filenames with ' just fine.
  -- GnuPlot, on the other hand, doesn't
  local gname = string.gsub(place,"'","-") -- Gnuplot title
  local fname = filenameCorrect(place) -- filename for this location
  if isDeath then
    fname = fname .. "-deaths"
  end

  if not dir then dir = "GNUplot/" end
  ------------------------------------------------------------------------
  -- Make the CSV data file
  local o = io.open(dir .. fname .. ".csv", "w")
  if not o then 
    print("Error opening " .. dir .. fname .. ".csv")
    os.exit(1)
  end
  o:write(makeHeaderString("csv"))
  o:write("\n")
  for date, data in sPairs(here.date) do
    local calculatedDoublingTime = data.calculatedDoublingTime
    if calculatedDoublingTime > data.cases then
      calculatedDoublingTime = data.cases
    end
    if calculatedDoublingTime > 200 then
      calculatedDoublingTime = 200
    end
    local line = makeString("csv",
                    date, data.cases, calculatedDoublingTime,
                    data.actualDoublingDays, data.delta, 
                    data.deltaAverage, data.casesPer100k or 0, 
                    data.herdImmunityCalc or -1,
                    data.averageGrowth)
    o:write(line)
    o:write("\n")
  end
  o:close()
  print(dir .. fname .. ".csv written")

  ------------------------------------------------------------------------
  -- Make the file with GNUplot directions (which uses the CSV file)
  -- o = io.open(dir .. fname .. ".gnuplot", "w")
  -- if not o then 
  --  print("Error opening " .. dir .. fname .. ".gnuplot")
  --  os.exit(1)
  -- end
  gFileHandle:write("set terminal pngcairo size 960,540 enhanced font '" ..
           fontnameSize .. "'\n")
  gFileHandle:write("set output '" .. fname .. ".png'\n")
  local dtime = "doubling time"
  if isDeath then dtime = "doubling time for deaths" end
  if here.mostRecentDate then
    gFileHandle:write("set title 'COVID-19 " ..dtime.. " for " .. gname ..
            " as of " .. here.mostRecentDate .. "'\n")
  else
    gFileHandle:write("set title 'COVID-19 " ..dtime.. " for " 
                      .. gname .. "'\n")
  end
  gFileHandle:write([=[set datafile separator ','
set xdata time
set timefmt "%Y-%m-%d"
set key left autotitle columnhead
set ylabel "Doubling Time"
set xlabel "Date]=])
  gFileHandle:write("\n")
  gFileHandle:write([=[
plot "]=] .. fname .. 
".csv" .. '"' .. " using 1:2 with lines lw 4, '' using 1:3 with lines lw 4\n")
  -- o:close()

  ------------------------------------------------------------------------
  -- Make a HTML file with the graph
  o = io.open(dir .. fname .. ".html", "w")
  if not o then 
    print("Error opening " .. dir .. fname .. ".html")
    os.exit(1)
  end
  if isDeath then
    o:write("<html><head><title>COVID-19 deaths for ")
  else
    o:write("<html><head><title>COVID-19 doubling time for ")
  end
  o:write(humanCounty(place))
  o:write("</title>\n")
  -- UTF-8 header
  o:write('<meta http-equiv="Content-Type" ')
  o:write('content="text/html; charset=utf-8">' .. "\n")
  -- Yes, I have made this page work on cell phone sized screens
  -- Also: Basic styling
  o:write([=[<meta name="viewport"
content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=0"
>]=])
    o:write(pageStyle())
    o:write(buttonBarStyle())
    o:write([=[
</head>
<body>
<div class=page>]=])
  if state[place] and not isDeath then
    o:write(buttonBarStateCases())
  elseif state[place] and isDeath then
    o:write(buttonBarStateDeaths())
  elseif place == "USA" and not isDeath then
    o:write(buttonBarUSACases())
  elseif place == "USA" and isDeath then
    o:write(buttonBarUSADeaths())
  else
    o:write(buttonBarSiteMap())
  end
  if isDeath then 
    o:write("<i>This is a graph showing COVID-19 deaths. ")
  else
    o:write("<i>This is a graph showing COVID-19 growth. ")
  end
  o:write("</i>\n")
  o:write("<h1>" .. humanCounty(place) .. "</h1>\n")
  o:write('<a href="' .. fname .. '.png">')
  o:write('<img src="' .. fname .. '.png" width=100%%></a><br>' .. "\n")
  o:write("<i>This image shows " ..dtime.. " for " .. humanCounty(place))
  if here.mostRecentDate then
    o:write(" as of " .. here.mostRecentDate)
  end
  o:write("</i>\n")
  o:write("<p>\n")
  local caseStrU = "Cases"
  if isDeath then caseStrU = "Deaths" end
  local caseStrL = "cases"
  if isDeath then caseStrL = "deaths" end

  if here.mostRecent and here.mostRecent.cases then
    o:write(caseStrU .. ": " .. 
            humanNumber(here.mostRecent.cases,",","%d") .. "\n")
  end 
  if here.mostRecent and here.mostRecent.casesPer100k then
    o:write("<br>" .. caseStrU .. " Per 100,000: " .. 
    humanNumber(here.mostRecent.casesPer100k) 
    .. "\n")
  end
  if here.mostRecent and here.mostRecent.delta14capita then 
    o:write("<br>" .. caseStrU .. " 14-day per 100k: " .. 
    humanNumber(here.mostRecent.delta14capita)
    .. "\n")
  end
  if here.mostRecent and here.mostRecent.deltaAverage then
    o:write("<br>New " ..caseStrL.. " (7-day average): " .. 
            humanNumber(here.mostRecent.deltaAverage) .. "\n")
  end
  if here.mostRecent and here.mostRecent.averageGrowth then
    o:write("<br>Growth: " .. 
            humanNumber((here.mostRecent.averageGrowth - 1) * 100) ..
            "%\n")
  end 
  if here.mostRecent and here.mostRecent.calculatedDoublingTime then
    if here.mostRecent.calculatedDoublingTime < 100 then
      o:write("<br>Doubling days (calculated): " .. 
             humanNumber(here.mostRecent.calculatedDoublingTime) ..
              "\n")
    else
      o:write("<br>Doubling days (calculated): > 100\n")
    end
  end 
  if here.mostRecent and here.mostRecent.actualDoublingDays then
    o:write("<br>Doubling days (actual): " .. 
            humanNumber(here.mostRecent.actualDoublingDays) ..
            "\n")
  end 
  o:write("<p>\n")
  o:write([=[The above graph shows <i>doubling time</i>, i.e. the number
of days it takes for ]=] ..caseStrL .. [=[ to double.  The purple line
is <i>calculated</i> doubling time: The number of days, based on 7-day
average growth, for cases to double.  The green line is <i>actual</i>
doubling time: How many days ago did we have half the number of cases.
In both cases, the higher the line, the slower the COVID-19 growth.<p>]=])
  -- Explain each and every figure in the above table.
  o:write([=[<i>]=]..caseStrU..[=[</i> is total COVID-19 ]=]
  ..caseStrL.. [=[; <i>]=]..caseStrL..[=[ per 100,000</i> is ]=]
  ..caseStrL.. [=[ per 100,000 people; <i>]=]..caseStrL..[=[ 14-day per
  100k</i> is the total number of ]=] ..caseStrL.. [=[ over the last 14 
  days, added together, then multiplied by 100,000, then divided by the 
  population. <i>New ]=]..caseStrL..[=[</i> is the number of ]=] 
  ..caseStrL.. [=[ we have had per day on average over the last seven 
  days.  <i>Growth</i> is the increase in ]=] ..caseStrL.. [=[ compared 
  to the previous number of ]=] ..caseStrL.. [=[; the number is a 7-day 
  average.  <i>Doubling days</i> is the number of days it will take for 
  ]=]..caseStrL..[=[ to double at the current growth rate (calculated), 
  or the number of days in the past we have had half the current number 
  of ]=] ..caseStrL.. " (actual).<p>\n")

  if state[place] and not isDeath then
    local countyList = {}
    o:write("<a name=CountyList> </a>\n")
    o:write("<h1>County list</h1>\n")
    for _,county in ipairs(state[place]["countyList"]) do
      if covidCases[county] and 
         covidCases[county].mostRecent and 
         covidCases[county].mostRecent.averageGrowth then
        countyList[county] = 
                        tonumber(covidCases[county].mostRecent.averageGrowth)
      else
        countyList[county] = 0
      end
    end
    for county,grow in sPairs(countyList) do
      local growFormat = humanNumber((grow - 1) * 100)
      local fCountyName = filenameCorrect(county)
      o:write('<a href="' .. fCountyName .. '.html">' .. humanCounty(county)
               .. "</a>")
      o:write(' Growth: ' ..  growFormat .. "%<br>\n")
    end
    o:write('<p><a href="USA.html">Return to USA</a> - ' .. "\n")
    o:write('<a href="index.html">Return to top</a> - ' .. "\n")
    o:write('<a href="' .. place .. '-deaths.html">Deaths for this state</a>')
    o:write('<br>' .. "\n")
  elseif (state[place] or place == "redStates" or place == "blueStates") 
      and isDeath then
    o:write('<p><a href="USA-deaths.html">Return to USA deaths</a> - ' .. "\n")
    o:write('<a href="index.html">Return to top</a> - ' .. "\n")
    o:write('<a href="' .. place .. '.html">COVID-19 cases for this state</a>')
    o:write('<br>' .. "\n")
  elseif place == "redStates" or place == "blueStates" then
    o:write('<p><a href="USA.html">Return to USA</a> - ' .. "\n")
    o:write('<a href="index.html">Return to top</a> - ' .. "\n")
    o:write('<a href="' .. place .. '-deaths.html">Deaths for this state</a>')
    o:write('<br>' .. "\n")
  elseif place == "USA" then
    o:write([=[<i>It is possible to get per-state ]=])
    if not isDeath then o:write("and per-county ") end
    o:write([=[growth
information.  Click on a state below to get growth information about that
state.]=])
    if not isDeath then 
      o:write([=[ Click on a county from the state page to get 
growth information about a single county]=])
    end
    o:write("</i><p>\n")
    o:write("<a name=StateList> </a>\n")
    if not isDeath then
      o:write("<h1>State list (cases)</h1>\n")
    else
      o:write("<h1>State list (deaths)</h1>\n")
    end
    o:write(stateHTMLlist)
    o:write('<p><a href="index.html">Return to top</a><br>' .. "\n")
  elseif not isDeath then
    if here.mostRecent and here.mostRecent.averageGrowth and
       here.mostRecent.cases and here.mostRecent.cases > 1000 then
      growthByCounty[place] = here.mostRecent.averageGrowth
    end
    o:write('<p>')
    if here.state then
      o:write('<a href="' .. here.state .. '.html">Return to ')
      o:write(here.state .. "</a> - \n")
    end
    o:write('<a href="USA.html">Return to USA</a> - ' .. "\n")
    o:write('<a href="index.html">Return to top</a><br>' .. "\n")
  end
  o:write("<p><i>"..showCopyright().."</i>")
  o:write("</div></body></html>\n")
  o:close()
  return growthByCounty
end
----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

gFileHandle = io.open("GNUplot/maps.gnuplot","w")
if not gFileHandle then print("Could not open .gnuplot file") os.exit(1) end

-------------------- Make an entire website in GNUplot/ -------------------- 
if arg[1] == "gnuplot" or arg[1] == "website" or arg[1] == "webquick" then

  -----------------------------------------------------------------------
  -- Let's get per-state growth summaries
  local growthByState = {}
  local dGrowthByState = {}
  local stateHTMLlist = ""
  local stateDeathHTMLlist = ""
  local stateHotSpots = ""
  local dir = "GNUplot/"
  for stateN,_ in sPairs(state) do
    local growth = 0
    local dGrowth = 0
    if covidCases[stateN] and 
       covidCases[stateN].mostRecent and 
       covidCases[stateN].mostRecent.averageGrowth then
      growthByState[stateN] = covidCases[stateN].mostRecent.averageGrowth
      growth = growthByState[stateN]
    end
    local growFormat = humanNumber((growth - 1) * 100)
    if covidDeaths[stateN] and 
       covidDeaths[stateN].mostRecent and 
       covidDeaths[stateN].mostRecent.averageGrowth then
      dGrowthByState[stateN] = covidDeaths[stateN].mostRecent.averageGrowth
      dGrowth = dGrowthByState[stateN]
    end
    local dFormat = humanNumber((dGrowth - 1) * 100)
    stateHTMLlist = stateHTMLlist .. 
        '<a href="' .. stateN .. '.html">' .. stateN .. "</a>" ..
        ' Growth: ' ..  growFormat .. "%<br>\n"
    stateDeathHTMLlist = stateDeathHTMLlist .. 
        '<a href="' .. stateN .. '-deaths.html">' .. stateN .. "</a>" ..
        ' Growth: ' ..  dFormat .. "%<br>\n"
  end
  local idx = 1
  for stateN,growth in sPairs(growthByState, sortedByRevValue) do
    if(idx <= 10) then
      local growFormat = humanNumber((growth - 1) * 100)
      stateHotSpots = stateHotSpots .. 
        '<a href="' .. stateN .. '.html">' .. stateN .. "</a>" ..
        ' Growth: ' ..  growFormat .. "%<br>\n"
    end
    idx = idx + 1
  end

  -- Create all of the web pages so we can explore growth by state and 
  -- county
  growthByCounty = {}
  if arg[1] ~= "webquick" then
    for place, here in sPairs(covidCases) do
      growthByCounty = makeAPage(place, here, growthByCounty, stateHTMLlist,
                                 dir, false, gFileHandle)
    end
  end

  -- Create all of the web pages for mortality (death) statistics
  for sName,_ in sPairs(state) do
    if covidDeaths[sName] then
      makeAPage(sName, covidDeaths[sName], {}, "", dir, true, gFileHandle)
    end
  end
  makeAPage("USA", covidDeaths["USA"], {}, stateDeathHTMLlist, dir, true,
    gFileHandle)
  makeAPage("redStates", covidDeaths["redStates"], {}, "", dir, true,
    gFileHandle)
  makeAPage("blueStates", covidDeaths["blueStates"], {}, "", dir, true,
    gFileHandle)
  --------------------------------------------------------------------------
  -- Now that we have all of the per-state and per-county pages (as well
  -- as a top-level USA.html page), let's make an index which lets us
  -- quickly see all of the hotspots

  -- First, make a SVG file
  local o = io.open(dir .. "hotSpots.svg", "w")
  o:write(makeSVG(covidCases,"averageGrowth",1.04,1.00))
  o:close()
  
  local o = io.open(dir .. "index.html", "w")
  o:write("<html><head><title>Sam Trenholme's COVID-19 tracker</title>")

  -- UTF-8 header
  o:write('<meta http-equiv="Content-Type" ')
  o:write('content="text/html; charset=utf-8">' .. "\n")

  -- Yes, the page works on cell phones.  Also, styling.
  o:write([=[<meta name="viewport"
content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=0"
>
</head>]=])
  o:write(pageStyle())
  o:write(buttonBarStyle())
  o:write("<body>\n<div class=page>\n")
  o:write(buttonBarToplevel())
  o:write("<h1>COVID-19 in the USA</h1>\n")
  o:write([=[<!--<b>Important note: This website is no longer being updated 
as of {{date}}</b>.  While COVID-19 continues to be a concern, with vaccines
widely available, growth has (in the USA at least) decreased to the point
COVID-19 is no longer the overriding concern it was in 2020.  Society is
slowly opening up again and we are getting closer to a post-pandemic
world every day.-->]=])
  o:write("\nCases: " ..
    humanNumber(covidCases.USA.mostRecent.cases, ",", "%d") .. " (" ..
    humanNumber(covidCases.USA.mostRecent.casesPer100k) .. " per 100,000)<br>")
  o:write("\nDeaths: " ..
    humanNumber(covidDeaths.USA.mostRecent.deaths, ",", "%d") .. " (" ..
    humanNumber(covidDeaths.USA.mostRecent.casesPer100k) .. " per 100,000)<p>")
  o:write([=[
<i>This is a map showing COVID-19 growth.  Red means fast (4% or higher)
growth; green means slow growth.
</i>
<p>
<a href="hotSpots.svg"><img src="hotSpots.svg" width=100%></a><br>]=])
  if all.USA.mostRecentDate then
    o:write("\n<i>Map current as of " .. all.USA.mostRecentDate .. "</i><p>\n")
  else
    o:write("<p>\n")
  end
  o:write("<a name=Top10States> </a>\n")
  o:write("<h2>Top 10 states</h2>\n")
  o:write("This is a list of the 10 states with the most COVID-19 growth:\n")
  o:write("<p>\n") 
  o:write(stateHotSpots) 
  o:write("\n<p><a href=statesByGrowth.html>See more states...</a>\n")
  o:write("<a name=Top20Counties> </a>\n")
  o:write("<h2>Top 20 counties</h2>\n")
  o:write("This is a list of the 20 counties with the most COVID-19 growth:\n")
  o:write("<p>\n") 
  local iex = 1
  for countyN, growth in sPairs(growthByCounty, sortedByRevValue) do
    if(iex < 20) and not string.match(countyN,'Unknown') then
      local growFormat = humanNumber((growth - 1) * 100)
      o:write('<a href="' .. countyN .. '.html">' .. humanCounty(countyN)
         .. "</a>" ..
        ' Growth: ' ..  growFormat .. "%<br>\n")
      iex = iex + 1
    end
  end 
  o:write("\n<p><a href=countyByGrowth.html>See more counties...</a>\n")
  o:write("<h2>States by political affiliation</h2>\n")
  o:write("This is the number of total COVID-19 cases for states where the\n")
  o:write("governor has a given political affiliation.<p>\n")
  o:write("<a href=blueStates.html>Democrat governors</a><br>\n")
  o:write("<a href=redStates.html>Republican governors</a>\n")
  o:write("<h1>Site map</h1>\n") 
  o:write("<a href=SiteMap.html>A site map is available</a>\n")
  o:write([=[<h1>See also</h1>
<ul>
<li><a href=https://covidtracking.com/>CovidTracking.com</a>
<li><a href=https://www.nytimes.com/interactive/2020/us/coronavirus-us-cases.html
>NY Times interactive map showing per-county COVID-19 growth</a><br>
<li><a href=https://coronavirus.jhu.edu/us-map>John Hopkins Coronavirus Resource Center</a><br>
<li><a href=https://www.worldometers.info/coronavirus/>WorldOmeter COVID-19 Coronavirus Pandemic information page</a>
<li><a href=https://coronavirus.1point3acres.com/en>1Point3Acres COVID-19 Tracker</a>
<li><a href=https://covid19risk.biosci.gatech.edu/>COVID-19 Event Risk
Assessment Planning Tool</a>
</ul>]=])
  o:write("<h1>Where to get this data</h1>\n")
  o:write(showCopyright())
  o:write("\n</div></body></html>\n")
  o:close()

  ------------------------------------------------------------------------
  -- States sorted by growth 
  o = io.open(dir .. "statesByGrowth.html", "w")
  if not o then print("Error opening statesByGrowth.html") os.exit(1) end
  o:write("<html><head><title>Sam Trenholme's COVID-19 tracker - ")
  o:write("states by growth</title>")
  writePageHeader(o)
  o:write("<h1>States sorted by COVID-19 growth</h1>\n")
  o:write("Figures are daily growth percentage (7-day average)<p>\n")
  o:write("<ol>\n")
  o:write(makeStatHTML(covidCases, "averageGrowth", "growth", 
          true, 55, "%.2f%%", true, "<li>", "", "</ol>"))
  o:write("<h1>See also</h1>\n")
  o:write("States sorted by: ")
  o:write("\n<a href=statesByCases100k.html>Cases per 100k</a>")
  o:write("\n-\n")
  o:write("\n<a href=statesByDeaths.html>Growth of deaths</a> - ")
  o:write("<a href=statesByDeaths100k.html>Deaths per 100k</a>")
  o:write("\n<p><a href=index.html>Return to top</a><p>\n")
  o:write(showCopyright())
  o:write("\n</div></body></html>\n")
  o:close()

  ------------------------------------------------------------------------
  -- States sorted by cases per capita
  o = io.open(dir .. "statesByCases100k.html", "w")
  if not o then print("Error opening statesByCases100k.html") os.exit(1) end
  o:write("<html><head><title>Sam Trenholme's COVID-19 tracker - ")
  o:write("states by cases per capita</title>")
  writePageHeader(o)
  o:write("<h1>States sorted by cases per 100k</h1>\n")
  o:write("This is a list of COVID-19 cases per 100,000 people")
  o:write("<ol>\n")
  o:write(makeStatHTML(covidCases, "casesPer100k", "per capita", 
          true, 55, "%.2f", false, "<li>", "", "</ol>"))
  o:write("</ol>\n")
  o:write("<h1>See also</h1>\n")
  o:write("States sorted by: ")
  o:write("\n<a href=statesByGrowth.html>Daily growth</a>")
  o:write("\n-\n")
  o:write("\n<a href=statesByDeaths.html>Growth of deaths</a> - ")
  o:write("<a href=statesByDeaths100k.html>Deaths per 100k</a>")
  o:write("\n<p><a href=index.html>Return to top</a><p>\n")
  o:write(showCopyright())
  o:write("\n</div></body></html>\n")
  o:close()

  ------------------------------------------------------------------------
  -- States sorted by growth of deaths
  o = io.open(dir .. "statesByDeaths.html", "w")
  if not o then print("Error opening statesByDeaths.html") os.exit(1) end
  o:write("<html><head><title>Sam Trenholme's COVID-19 tracker - ")
  o:write("states by growth of deaths</title>")
  writePageHeader(o)
  o:write("<h1>States sorted by COVID-19 deaths</h1>\n")
  o:write("Figures are daily increase percentage (7-day average)<p>\n")
  o:write("<ol>\n")
  o:write(makeStatHTML(covidDeaths, "averageGrowth", "growth", 
          true, 55, "%.2f%%", true, "<li>", "-deaths", "</ol>"))
  o:write("</ol>\n")
  o:write("<h1>See also</h1>\n")
  o:write("States sorted by: ")
  o:write("\n<a href=statesByGrowth.html>Growth of cases</a> - ")
  o:write("\n<a href=statesByCases100k.html>Cases per 100k</a>")
  o:write("\n-\n")
  o:write("<a href=statesByDeaths100k.html>Deaths per 100k</a>")
  o:write("\n<p><a href=index.html>Return to top</a><p>\n")
  o:write(showCopyright())
  o:write("\n</div></body></html>\n")
  o:close()

  ------------------------------------------------------------------------
  -- States sorted by deaths per capita
  o = io.open(dir .. "statesByDeaths100k.html", "w")
  if not o then print("Error opening statesByDeaths100k.html") os.exit(1) end
  o:write("<html><head><title>Sam Trenholme's COVID-19 tracker - ")
  o:write("states by deaths per capita</title>")
  writePageHeader(o)
  o:write("<h1>States sorted by deaths per 100k</h1>\n")
  o:write("This is a list of COVID-19 deaths per 100,000 people")
  o:write("<ol>\n")
  o:write(makeStatHTML(covidDeaths, "casesPer100k", "per capita", 
          true, 55, "%.2f", false, "<li>", "-deaths", "</ol>"))
  o:write("</ol>\n")
  o:write("<h1>See also</h1>\n")
  o:write("States sorted by: ")
  o:write("\n<a href=statesByGrowth.html>Daily growth</a>\n")
  o:write("- <a href=statesByCases100k.html>Cases per 100k</a>")
  o:write("\n-\n")
  o:write("\n<a href=statesByDeaths.html>Growth of deaths</a>")
  o:write("\n<p><a href=index.html>Return to top</a><p>\n")
  o:write(showCopyright())
  o:write("\n</div></body></html>\n")
  o:close()

  ------------------------------------------------------------------------
  -- Counties sorted by growth 
  o = io.open(dir .. "countyByGrowth.html", "w")
  if not o then print("Error opening countyByGrowth.html") os.exit(1) end
  o:write("<html><head><title>Sam Trenholme's COVID-19 tracker - ")
  o:write("counties by growth</title>")
  writePageHeader(o)
  o:write("<h1>Counties sorted by COVID-19 growth</h1>\n")
  o:write("Figures are daily growth percentage (7-day average)<p>\n")
  o:write("<ol>\n")
  local iey = 1
  for countyN, growth in sPairs(growthByCounty, sortedByRevValue) do
    if(iey <= 100) and not string.match(countyN,'Unknown') then
      local growFormat = humanNumber((growth - 1) * 100)
      o:write('<li><a href="' .. countyN .. '.html">' .. 
        humanCounty(countyN) .. "</a>" ..
        ' Growth: ' ..  growFormat .. "%<br>\n")
      iey = iey + 1
    end
  end 
  o:write("\n</ol>\n")
  o:write("<i>Note: Only counties with 1,000 or more cases are listed</i>\n")
  o:write("<p><a href=index.html>Return to top</a><p>\n")
  o:write(showCopyright())
  o:write("\n</div></body></html>\n")
  o:close()

  --------------------------------------------------------------------------
  -- Site map
  o = io.open(dir .. "SiteMap.html", "w")
  if not o then print("Error opening SiteMap.html") os.exit(1) end
  o:write("<html><head><title>Sam Trenholme's COVID-19 tracker - ")
  o:write("site map</title>")
  writePageHeader(o, buttonBarToplevel)
  o:write("<h1>Site map</h1>\n")
  o:write("<a href=index.html>Index; heat map of the US</a><p>\n")
  o:write("<a href=USA.html>Overall COVID-19 case growth information</a>")
  o:write("<br>\n")
  o:write("Case growth information by state: ")
  for longName, abbr in sPairs(stateNameAbbr) do
    o:write('<a href="' ..longName.. '.html">' ..abbr.. '</a> ')
  end
  o:write("<br><i>To get county-level information click on the state with ")
  o:write("the desired county</i><p>")
  o:write("<a href=USA-deaths.html>COVID-19 death growth information</a>")
  o:write("<br>\n")
  o:write("Mortality growth information by state: ")
  for longName, abbr in sPairs(stateNameAbbr) do
    o:write('<a href="' ..longName.. '-deaths.html">' ..abbr.. '</a> ')
  end
  o:write("<p>\n")
  o:write("<a href=statesByGrowth.html>States by daily COVID-19 growth</a>")
  o:write("<br>\n")
  o:write("<a href=statesByCases100k.html>States by cases per 100,000</a>")
  o:write("<br>\n")
  o:write("<a href=statesByDeaths.html>States by daily COVID-19 mortality ")
  o:write("growth</a>")
  o:write("<br>\n")
  o:write("<a href=statesByDeaths100k.html>States by deaths per 100,000</a>")
  o:write("<p>\n")
  o:write("<a href=countyByGrowth.html>Counties sorted by COVID-19 growth</a>")
  o:write("<p>\n")
  o:write("<a href=redStates.html>COVID-19 daily growth for all states ")
  o:write("with a Republican governor</a> (")
  o:write("<a href=redStates-deaths.html>deaths</a>)<br>\n")
  o:write("<a href=blueStates.html>COVID-19 daily growth for all states ")
  o:write("with a Democrat governor</a> (")
  o:write("<a href=blueStates-deaths.html>deaths</a>)<p>\n")
  o:write(showCopyright())
  o:write("\n</div></body></html>\n")
  o:close()

end

