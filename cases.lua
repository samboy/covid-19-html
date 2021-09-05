require("blackCastle")
cases=blackCastle("cases-alltime.json")
links=blackCastle("links-alltime.json")
cFind = {}

for a=1,#cases do
  c = cases[a]
  if c["id"] then
    cFind[c["id"]] = c
  end
end

isVac = 0
isVacAndAsymp = 0
notVax = 0
unknown = 0
for a=1,#links do 
  i=links[a]["infector"] 
  c = cFind[i]
  if c and c["vaccinated"] and c["vaccinated"]:find("2 dose") then 
    isVac = isVac+1
    if c["asymptomatic"] and c["asymptomatic"]:find("y") then 
      isVacAndAsymp =isVacAndAsymp +1 
    end
  else
    if c then notVax = notVax + 1
    else unknown = unknown + 1
    end
  end
end
print("isvac", isVac)
print("isVacAndAsymp", isVacAndAsymp)
print("notVax", notVax)
print("unknown", unknown)
