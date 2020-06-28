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

io.input("data.csv")
all = {}
g_dayrange = 7

-- Initialize a given location's data
function initPlaceData() 
  out = { casesHistory = {}, rollingAverage = {}, deltaList = {},
	  n = 0, hadHalf = 1, last = 0, date = {} }
  return out;
end

line = io.read() -- Discard first line (fields)
while line do
  line = io.read()
  if not line then break end
  fields = rCharSplit(line,",")
  date = fields[1]
  place = fields[2] .. "," .. fields[3]
  if not all[place] then all[place] = initPlaceData() end
  here = all[place]
  here.date[date] = {}
  today = here.date[date]
  here.mostRecent = today -- We assume input is date-sorted
  
  here.n = here.n + 1

  -- Get information from the comma separated line
  today.cases = tonumber(fields[5])
  today.deaths = tonumber(fields[6])

  -- Calculate actual doubling time (when we had half the cases compared
  -- to a given day)
  here.casesHistory[here.n] = cases
  here.noHalf = 0
  while here.casesHistory[here.hadHalf] and 
        here.casesHistory[here.hadHalf] < (here.cases / 2) do
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
  if g_dayrange > 0 and math.log(today.sum / g_dayrange) > 0 then
    today.calculatedDoublingTime = 
        math.log(2) / math.log(today.sum / g_dayrange)
  end
end

tablePrint(all)
