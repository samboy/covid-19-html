#!/usr/bin/env lua-5.1

require("LUAstuff")
require("stateNameAbbr")
require("USmap")
-------------------------------- process args --------------------------------
if #arg == 0 or arg[1] == '--help' then
  print [=[Usage:

	examine-growth [action] [args]

Action can be either "--help" to show this message, or "cases" to show
the cases for a given location by day, or "csv" to show the cases in
CSV format suitable for importing in to a spreadsheet to make a chart.

If "action" is "cases" or "csv", the following args are (in order)

* County or State name we print data for.  Use County,State to specify
  a given county in a given state.  Should we have both a state and county
  with a name, we use the state name.  Should we have a county which is
  in multiple states, one will be chosen pseudo-randomly, unless state
  is also specified.  Use "USA" to look at overall national numbers.
* Day range: How many days do we average some numbers over. Default: 7
* Do deaths: If this is "1", process deaths, not cases. Default: 0

If action is "svg", we output, on standard output, a SVG map of the 
United States for a given field.  Cyan means things look good, red means
things look bad.  Arguments for "svg" are:

* Field: What to visualize.  Can be one of "averageGrowth", (how
  much growth have we seen over the last N days, where N is the
  day range), "actualDoublingDays", "calculatedDoublingTime", 
  "casesPer100k", or "herdImmunityCalc" (how long it would take 
  for a large portion of the population to have COVID-19).
  Default is "averageGrowth".
* Day range: How many days do we average some numbers over. Default: 7
* Do deaths: If this is "1", process deaths, not cases. Default: 0

If action is "hotSpots", list locations with what appears to be
dangerous COVID-19 growth, based on fuzzy heuristic

  ]=]
  os.exit(0)
end
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
-- NUmbers obtained from the Wikipedia 2020-07-03
if not pop["Alaska"] then pop["Alaska"]=710249 end
if not pop["District of Columbia"] then pop["District of Columbia"]=705749 end
if not pop["Louisiana"] then pop["Louisiana"]=4648794 end
  
io.input("data.csv")
all = {}
g_dayrange = 7

-- Initialize a given location's data
function initPlaceData() 
  out = { casesHistory = {}, rollingAverage = {}, deltaList = {},
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
  if not all[place] then all[place] = initPlaceData() end
  here = all[place]
  here.county = fields[2]
  here.state = fields[3]
  here.pop = pop[place]
  here.date[date] = {}
  today = here.date[date]
  
  -- Get information from the comma separated line
  today.cases = tonumber(fields[5]) or 0
  today.deaths = tonumber(fields[6]) or 0
end

-- Add up numbers in a state to get a by-state total
state = {}
USA = initPlaceData()
for place, here in sPairs(all) do
  if not state[here.state] then state[here.state] = initPlaceData() end
  for date, today in sPairs(here.date) do
    if not state[here.state].date[date] then 
      state[here.state].date[date] = {} 
    end
    if not USA.date[date] then USA.date[date] = {} end
    if not state[here.state].date[date].cases then
      state[here.state].date[date].cases = 0
    end
    if not USA.date[date].cases then USA.date[date].cases = 0 end
    if not state[here.state].date[date].deaths then
      state[here.state].date[date].deaths = 0
    end
    if not USA.date[date].deaths then USA.date[date].deaths = 0 end
    state[here.state].date[date].cases = state[here.state].date[date].cases +
        today.cases
    state[here.state].date[date].deaths = state[here.state].date[date].deaths +
        today.deaths
    USA.date[date].cases = USA.date[date].cases + today.cases
    USA.date[date].deaths = USA.date[date].deaths + today.deaths
  end
end
for state, here in sPairs(state) do
   all[state] = here
   all[state].pop = pop[state]
end
all["USA"] = USA
all["USA"].pop = USpop
   
-- Process the totals we have to get growth rates and other calculated data 
for place, here in sPairs(all) do
  for date, today in sPairs(here.date) do
    here.mostRecent = today 
    here.n = here.n + 1

    -- Calculate actual doubling time (when we had half the cases compared
    -- to a given day)
    if g_doDeaths then
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
    today.deltaSum = 0
    for a = 0, g_dayrange do
      if here.deltaList[a] then
        today.deltaSum = today.deltaSum + here.deltaList[a]
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
    end

    -- Estimate when we will have "Herd immunity".  Here, "Herd immunity"
    -- is how long, based on estimated doubling time, it would take
    -- for 10% of the population to have a COVID-19 case (we presume the
    -- other 90% are asymptomatic) 
    if here.pop and math.log(today.averageGrowth) > 0 and today.cases > 0 then
      today.herdImmunityCalc = math.log((here.pop / 10) / today.cases) /
          math.log(today.averageGrowth)
    end
    -- When looking at deaths, "herd Immunity" is a meaningless number
    if g_doDeaths then today.herdImmunityCalc = -1 end

  end
end

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

-- Header string for tabulated output
function makeHeaderString()
  if g_outputFormat == "csv" then return
    "Date,Doubling time (calculated days),Doubling time (actual days),Cases"
  else return
    "Date          Cases   Doubling time        New daily cases"
  end
end
    
-- Make Output string once we have the data to output
function makeString(date, cases,calculatedDoublingTime,actualDoublingDays,
        delta, deltaAverage, casesPer100k, herdImmunityCalc)
  if g_outputFormat == "csv" then
    return string.format("%s,%f,%d,%d,%.2f,%.2f",date, calculatedDoublingTime,
      actualDoublingDays, cases, casesPer100k, herdImmunityCalc)
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

  for date, data in sPairs(here.date) do
    line = makeString(date, data.cases, data.calculatedDoublingTime,
                      data.actualDoublingDays, data.delta, 
                      data.deltaAverage, data.casesPer100k, 
                      data.herdImmunityCalc or -1)
    print(line)
  end
  os.exit(0)
end

-------------------- make a map of a single datapoint --------------------
if arg[1] == "svg" then
  max = 0
  min = 100000
  -- Find "max" so we have 0 <-> 1 gradient
  for state, sAbbr in sPairs(stateNameAbbr) do
    if all and all[state] and all[state]["mostRecent"] and 
       all[state]["mostRecent"][g_field] then
      local t = all[state]["mostRecent"][g_field]
      if t > max then max = t end
      if t < min then min = t end
    end
  end
  -- Make a string with a color for each state
  repl = ""
  for state, sAbbr in sPairs(stateNameAbbr) do
    if all and all[state] and all[state]["mostRecent"] and
       all[state]["mostRecent"][g_field] then
      local t = all[state]["mostRecent"][g_field]
      local u 
      if t >= min and t <= max then u = (t - min) / (max - min) else t = -1 end
      if u >=0 then
        if g_field == "calculatedDoublingTime" 
            or g_field == "actualDoublingDays" then
          color = calcColor(0xff, 0x00, 0x00, 0x00, 0xff, 0xff, u)
        else
          color = calcColor(0x00, 0xff, 0xff, 0xff, 0x00, 0x00, u)
        end
        repl = repl .. "#" .. sAbbr .. "{fill: #" .. color .. ";}" ..
               "<!-- " .. tostring(t) .. "-->\n"
      end
    end
  end
  out = string.gsub(USmapSVG,'<!..COLORS..>',repl)
  print(out)
end
