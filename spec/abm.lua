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
-- barlabels.lua is a standalone static label table (no WoW API), safe anywhere.
local FILES = {
  "libs/base64.lua",
  "libs/crc32.lua",
  "serialize.lua",
  "barlabels.lua",
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

---@param extra table? additional addon files to load after the pure-Lua set
---@param nui table? LibNUI double from abm.nui(), installed as ns.ui / ns.Colors
---        BEFORE `extra` loads (widget-building files capture them at load time)
---@return table ns a fresh Action Bar Master namespace with the pure-Lua modules loaded
function abm.load(extra, nui)
  _G.bit = _G.bit or makeBit()
  _G.IsWindowsClient = _G.IsWindowsClient or function() return false end
  local ns = {}
  for _, f in ipairs(FILES) do
    assert(loadfile(f))("ActionBarMaster", ns)
  end
  if nui then
    ns.ui, ns.Colors = nui.ui, nui.Colors
  end
  for _, f in ipairs(extra or {}) do
    assert(loadfile(f))("ActionBarMaster", ns)
  end
  return ns
end

---Minimal stand-in for the LibNUI widget surface, enough to let a pure-logic
---builder (barselect.lua) construct its frames headlessly. Widgets are inert
---tables whose setters no-op and chain; every Button is recorded in `buttons` in
---creation order, so a spec can drive `chip.OnClick()` the way the real widget's
---OnClick script does. Deliberately thin — it doubles only what barselect.lua
---touches, so anything relying on real layout/rendering stays in-game-tested.
---@return table nui { ui = table, Colors = table, buttons = table }
function abm.nui()
  local nui = { buttons = {} }

  local function widget(init)
    local w = {}
    for k, v in pairs(init or {}) do w[k] = v end
    w._widget = setmetatable({}, { __index = function() return function() end end })
    w.Color     = function(self) return self end
    w.TextAlign = function(self) return self end
    w.Text      = function(self, t)
      if t == nil then return self._text end
      self._text = t
      return self
    end
    return w
  end

  local function class(onNew)
    local c = {}
    c.new = function(_, init)
      local w = widget(init)
      if onNew then onNew(w) end
      return w
    end
    return c
  end

  nui.ui = {
    Label   = class(),
    Texture = class(),
    Button  = class(function(w)
      -- LibNUI turns the `background` colour arg into a texture on the widget
      w.background = widget()
      nui.buttons[#nui.buttons + 1] = w
    end),
    -- Anchor/layer enums are only ever passed straight back into position tables.
    edge  = setmetatable({}, { __index = function(_, k) return k end }),
    layer = setmetatable({}, { __index = function(_, k) return k end }),
  }
  nui.Colors = { rgba = function(r, g, b, a) return { r, g, b, a } end }

  return nui
end

---Install a fake action bar over the WoW pickup/place globals.
---
---Call this BEFORE abm.load(): restore_slots.lua captures PickupSpell (and friends)
---into file-local upvalues at load time, so a stub installed afterwards is never seen.
---The slot globals (GetActionInfo/PickupAction/PlaceAction) are looked up per call and
---so are order-independent, but keeping one call site avoids the distinction mattering.
---
---Both PickupAction and PlaceAction SWAP slot and cursor, as they do in game — that
---swap is exactly what turned "pick the action up to clear it" into a round-trip (#131),
---so the harness has to model it rather than treat pickup as a plain removal.
---@param initial table? { [slotID] = { type, index } } starting bar contents
---@return table bars { slots = table, cursor = table|nil }
function abm.actionbars(initial)
  local bars = { slots = {}, cursor = nil }
  for id, action in pairs(initial or {}) do
    bars.slots[id] = { action[1], action[2] }
  end

  local function swap(id)
    bars.slots[id], bars.cursor = bars.cursor, bars.slots[id]
  end

  _G.GetActionInfo = function(id)
    local a = bars.slots[id]
    if not a then return nil end
    return a[1], a[2]
  end
  _G.PickupAction  = function(id) swap(id) end
  _G.PlaceAction   = function(id) swap(id) end
  _G.GetCursorInfo = function()
    local c = bars.cursor
    if not c then return nil end
    return c[1], c[2]
  end
  _G.ClearCursor  = function() bars.cursor = nil end
  _G.PickupSpell  = function(id) bars.cursor = { "spell", id } end

  return bars
end

return abm
