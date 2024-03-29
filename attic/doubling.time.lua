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

----------------------- Read by-county population data -----------------------
io.input("co-est2019-annres.csv")
line = ""
pop = {}
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
end
io.close()

----------------------- Process command line arguments -----------------------
g_search = arg[1]
g_dayrange = tonumber(arg[2]) or nil
g_doDeaths = arg[3]
g_outputFormat = "space"
if(string.find(arg[0],"csv")) then
  g_outputFormat = "csv"
end
-- Default values
if not g_search then g_search = "San Diego" end
if not g_dayrange then g_dayrange = 7 end
if not g_doDeaths or tonumber(g_doDeaths) == 0 then 
  g_doDeaths = false 
else 
  g_doDeaths = true 
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

io.input("data.csv")
line = ""
casesHistory = {}
rollingAverage = {}
deltaList = {}
n = 0
hadHalf = 1
last = 0

-- Header describing fields
if g_outputFormat == "csv" then
  print(
      'Date,Doubling time (calculated days),Doubling time (actual days),Cases')
else 
  print('Date          Cases   Doubling time        New daily cases')
end

while line do
  line = io.read()
  if not line then break end
  if string.find(line,g_search) then

    n = n + 1

    -- Get information from the comma separated line
    fields = rCharSplit(line,",")
    date = fields[1]
    cases = tonumber(fields[5])
    deaths = tonumber(fields[6])
    place = fields[2] .. "," .. fields[3]

    -- Calculate actual doubling time (when we had half the cases compared
    -- to a given day)
    casesHistory[n] = cases
    noHalf = 0
    while casesHistory[hadHalf] and casesHistory[hadHalf] < (cases / 2) do
      hadHalf = hadHalf + 1
      if hadHalf > n then
        noHalf = 1
	hadHalf = 1
	break
      end
    end
    if hadHalf > 1 and noHalf == 0 then
      actualDoublingDays = 1 + n - hadHalf
    else
      actualDoublingDays = 0
    end

    -- Calculate an average growth over a range of days
    local growth = 0
    if last > 0 then
      growth = cases / last
    else
      growth = 0
    end
    rollingAverage[n % g_dayrange] = growth
    local sum = 0
    for a = 0, g_dayrange do
      if rollingAverage[a] then
        sum = sum + rollingAverage[a]
      end
    end
    averageGrowth = sum / g_dayrange

    -- Calculate the yesterday and average daily increase in cases
    local delta = cases - last
    deltaList[n % g_dayrange] = delta
    local deltaSum = 0
    for a = 0, g_dayrange do
      if deltaList[a] then
        deltaSum = deltaSum + deltaList[a]
      end 
    end
    if g_dayrange > 0 then
      deltaAverage = deltaSum / g_dayrange
    end

    -- Last is yesterday's case count
    last = cases

    -- Calculate the projected doubling time
    local calculatedDoublingTime = 0
    if g_dayrange > 0 and math.log(averageGrowth) > 0 then
      calculatedDoublingTime = math.log(2) / math.log(averageGrowth)
    end

    casesPer100k = -1
    herdImmunityCalc = -1

    -- Cases per 100,000 people
    if pop[place] and pop[place] > 0 then
      casesPer100k = (cases / pop[place]) * 100000
    end
   
    -- Estimate when we will have "Herd immunity".  Here, "Herd immunity"
    -- is how long, based on estimated doubling time, it would take
    -- for 10% of the population to have a COVID-19 case (we presume the
    -- other 90% are asymptomatic)
    if pop[place] and math.log(averageGrowth) > 0 and cases > 0 then
      herdImmunityCalc = math.log((pop[place] / 10) / cases) /
          math.log(averageGrowth)
    end
    
    -- Make output format string
    outstring = makeString(date, cases, calculatedDoublingTime,
        actualDoublingDays, delta, deltaAverage, casesPer100k, 
        herdImmunityCalc)
    print(outstring)
  end
end

