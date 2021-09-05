-- Lua/Lunacy script to parse JSON from Singapore data

-- blackCastle.lua is a quick and dirty Lua JSON parser I whipped up
require("blackCastle")
-- Let's read https://covid.viz.sg/data/cases-alltime.json
cases=blackCastle("cases-alltime.json")
-- Likewise, https://covid.viz.sg/data/links-alltime.json
links=blackCastle("links-alltime.json")

-- Let's make a table where the key is the case number
cFind = {}
for a=1,#cases do
  c = cases[a]
  if c["id"] then
    cFind[c["id"]] = c
  end
end

-- Now, let's count vaccinated and unvaccinated
isVac = 0
isVacAndAsymp = 0
notVax = 0
unknown = 0
for a=1,#links do 
  i=links[a]["infector"] 
  c = cFind[i]
  -- If they have two doses, they're vaccinated
  -- (Does Singapore use the J&J vaccine)
  if c and c["vaccinated"] and c["vaccinated"]:find("2 dose") then 
    isVac = isVac+1
    -- Let's count the vaccinated + asymptomatic ones
    if c["asymptomatic"] and c["asymptomatic"]:find("y") then 
      isVacAndAsymp =isVacAndAsymp +1 
    end
  else
    -- If not vaccinated twice, we count it as unvaccinated
    if c then notVax = notVax + 1
    else unknown = unknown + 1
    end
  end
end

-- Print tallies
print("isvac", isVac)
print("isVacAndAsymp", isVacAndAsymp)
print("notVax", notVax)
print("unknown", unknown)
