-- LUA is a "no batteries included" language (it's also under 120k in
-- size for my size-optimized Win32 binary of Lunacy, a small Lua fork)
-- This has some of the stuff Lua is missing (a regex splitter, sorted
-- table iterator, etc.)
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

-- Given two RGB colors and a value from 0 to 1, find a color between
-- those two colors.  Output the color as hex.  The colors will be 
-- between 0 and 255
function calcColor(r1, g1, b1, r2, g2, b2, value)
  if value < 0 or value > 1 then return '00ffff' end -- Error
  if r1 < 0 or r1 > 255 or g1 < 0 or g1 > 255 or b1 < 0 or b1 > 255 or
     r2 < 0 or r2 > 255 or g2 < 0 or g2 > 255 or b2 < 0 or b2 > 255 then
    return '00ffff' -- Error
  end
  r = (r1 * value + r2 * (1 - value)) / 2
  g = (g1 * value + g2 * (1 - value)) / 2
  b = (b1 * value + b2 * (1 - value)) / 2
  return string.format("%02x%02x%02x",r,g,b)
end

