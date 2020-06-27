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

----------------------- Process command line arguments -----------------------
g_search = arg[1]
g_dayrange = tonumber(arg[2]) or nil
g_doDeaths = arg[3]
if not g_search then g_search = "San Diego" end
if not g_dayrange then g_dayrange = 7 end

if not g_doDeaths or tonumber(g_doDeaths) == 0 then 
  g_doDeaths = false 
else 
  g_doDeaths = true 
end

io.input("data.csv")
line = ""
casesHistory = {}
n = 0
hadHalf = 1
last = 0
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
      actualDoublingDays = -1
    end

    print(date,actualDoublingDays) -- DEBUG

  end
end

