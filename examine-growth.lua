#!/usr/bin/env lua-5.1
----------------------- rSplit() -----------------------
-- Input: A string we will split, a character (class) we split on
-- Output: An array (numeric indexed table) with the split string
-- Should the character we split on not be in the string to split,
-- we will have a one-element array with the input string
-- Example usage:
-- a = "1,2,3" t = rSplit(a,",") for k,v in pairs(t) do print(k,v) end
function rCharSplit(i, c)
  local out = {}
  local n = 1
  local q

  -- For one-character separators, like ",", we allow empty fields
  if string.len(tostring(c)) == 1 then
    i = string.gsub(i, tostring(c) .. tostring(c),
                    tostring(c) .. " " .. tostring(c))
  end

  for q in string.gmatch(i, "[^" .. tostring(c) .. "]+") do
    out[n] = q
    n = n + 1
  end
  return out
end

----------------------- sortedTableKeys() -----------------------
--  Input: A table
--  Output: An array (i.e. table with only numeric keys, starting at 1
--          and counting upwards without any gaps in the numeric sequence)
--          with the input table's keys lexically (alphabetically) sorted
--
--  I created this routine when I wanted to make a version of pairs()
--  guaranteed to traverse a table in a (mostly) deterministic fashion.

function sortedTableKeys(t)
  local a = {}
  local b = 1
  for k,_ in pairs(t) do -- pairs() use OK; will sort
    a[b] = k
    b = b + 1
  end
  table.sort(a, function(y,z) return tostring(y) < tostring(z) end)
  return a
end

----------------------- tablePrint() -----------------------
-- Print out a table on standard output.  Traverse sub-tables, avoid
-- circular traversals.  The code here has three arguments, but
-- we only need one argument when looking at a table; the "prefix"
-- and "seen" arguments are only used when tablePrint recursively looks
-- at a sub-table.
-- Usage
-- t = {foo = "bar", baz = "b"} t2 = {l1 = "hi", t1 = t} t.z = t2 tablePrint(t)
function tablePrint(t, prefix, seen)
  if not seen then
    seen = {}
    seen[tostring(t)] = true
  end
  for k,v in sPairs(t) do
    if type(v) == "table" then
      if not seen[tostring(v)] then
        seen[tostring(v)] = true
        local prefixR
        if prefix then
          prefixR = prefix .. ">" .. tostring(k) .. ":"
        else
          prefixR = tostring(k) .. ":"
        end
        tablePrint(t[k],prefixR,seen)
      else
        if prefix then
          print(prefix, k, v, "Already seen, not traversing")
        else
          print(k, v, "Already seen, not traversing")
        end
      end
    else
      if prefix then
        print(prefix, k, v)
      else
        print(k, v)
      end
    end
  end
end

----------------------- sPairs(t) -----------------------
-- Input: Table
-- Ouput: Iterator used by "for" which will go through the keys in
-- a table in a sorted order, e.g.
-- someTable = {foo = "bar", bar = "hello" , aaa = "zzz", aab = "xyz" }
-- for key, value in sPairs(someTable) do print(key, value) end
function sPairs(t)
  local function _tableIter(t, _)
    local k = t.s[t.i]
    local v
    if k then
      v = t.t[k]
    else
      return nil
    end
    t.i = t.i + 1
    if v then
      return k, v
    end
  end
  local tt = {}
  tt.s = sortedTableKeys(t)
  tt.t = t
  tt.i = 1
  return _tableIter, tt, nil
end

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
