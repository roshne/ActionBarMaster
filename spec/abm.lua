-- Loads Action Bar Master's WoW-API-free modules into a fresh namespace,
-- passing the (addonName, ns) vararg WoW gives each addon file. Specs call
-- abm.load() for an isolated ns per test. Paths are relative to the repo root,
-- where busted runs.
--
-- serialize.lua needs a `bit` library and IsWindowsClient at load time; both
-- are stubbed here so no luarocks bit module is required. WoW's bit.bor/band
-- are VARIADIC (Decode folds 4 args into one bor) — the stub matches that, the
-- footgun a 2-arg fallback would silently reintroduce.

local abm = {}

-- Load order matters: serialize.lua captures ns.base64 / ns.crc32 at load.
local FILES = {
  "libs/base64.lua",
  "libs/crc32.lua",
  "serialize.lua",
}

-- Pure-Lua 32-bit ops matching WoW's `bit` library (variadic band/bor/bxor).
local function makeBit()
  local WRAP = 0x100000000
  local function norm(x) return x % WRAP end
  local function binop(a, b, f)
    a, b = norm(a), norm(b)
    local res, place = 0, 1
    for _ = 1, 32 do
      local abit, bbit = a % 2, b % 2
      if f(abit, bbit) == 1 then res = res + place end
      a, b, place = (a - abit) / 2, (b - bbit) / 2, place * 2
    end
    return res
  end
  local function fold(f)
    return function(x, ...)
      x = norm(x)
      for i = 1, select("#", ...) do x = binop(x, (select(i, ...)), f) end
      return x
    end
  end
  return {
    band   = fold(function(a, b) return (a == 1 and b == 1) and 1 or 0 end),
    bor    = fold(function(a, b) return (a == 1 or b == 1) and 1 or 0 end),
    bxor   = fold(function(a, b) return (a ~= b) and 1 or 0 end),
    lshift = function(a, n) return norm(a * 2 ^ n) end,
    rshift = function(a, n) return math.floor(norm(a) / 2 ^ n) end,
  }
end

---@return table ns a fresh Action Bar Master namespace with the pure-Lua modules loaded
function abm.load()
  _G.bit = _G.bit or makeBit()
  _G.IsWindowsClient = _G.IsWindowsClient or function() return false end
  local ns = {}
  for _, f in ipairs(FILES) do
    assert(loadfile(f))("ActionBarMaster", ns)
  end
  return ns
end

return abm
