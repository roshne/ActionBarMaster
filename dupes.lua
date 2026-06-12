local _, ns = ...
local ui = ns.ui

local WIN_W   = 560
local WIN_H   = 400
local PAD     = 8
local ROW_H   = 22
local ACK_W   = 72
local BTN_H   = 22
local SCAN_W  = 60
local CHAR_W  = 110
local TOGGL_W = 90

local function getAcked()
  if not ns.db.ackedDupes then ns.db.ackedDupes = {} end
  return ns.db.ackedDupes
end

-- Stable identity key for a slot. nil for ephemeral types.
-- Macros keyed by name+body so re-captures don't re-flag.
local function actionKey(slot, macroById)
  local t = slot.type
  if t == "petaction" or t == "futurespell" then return nil end
  if t == "macro" then
    local m = macroById[slot.index]
    return m and ("macro|" .. m.name .. "|" .. m.body)
               or ("macro|?" .. (slot.index or 0))
  end
  if t == "summonpet"  then return "summonpet|"  .. (slot.strindex or "") end
  if t == "profession" then
    return "profession|" .. (slot.index or 0) .. "|" .. (slot.profSlot or slot.strindex or "")
  end
  return t .. "|" .. (slot.index or 0)
end

-- Best-effort human-readable label for an action key.
local function actionLabel(key)
  local t  = key:match("^([^|]+)|")
  local id = tonumber(key:match("|(%d+)$"))
  if (t == "spell" or t == "racial") and id then
    return GetSpellInfo and GetSpellInfo(id) or key
  end
  if t == "item" and id then return GetItemInfo and GetItemInfo(id) or key end
  if t == "flyout" and id then
    local name = GetFlyoutInfo and GetFlyoutInfo(id)
    return name and ("Flyout: " .. name) or key
  end
  if t == "summonmount" and id then
    local name = C_MountJournal and C_MountJournal.GetMountInfoByID(id)
    return name and ("Mount: " .. name) or key
  end
  if t == "macro"     then return "Macro: " .. (key:match("^macro|([^|]+)|") or "?") end
  if t == "summonpet" then return "Pet: " .. (key:match("|(.-)$") or "?"):sub(1, 10) .. "..." end
  return key
end

-- Slot ID -> "Bar Label #col"
local function slotLabel(slotID)
  return ns.GetBarLabel(math.ceil(slotID / 12)) .. " #" .. ((slotID - 1) % 12 + 1)
end

-- Decode all profiles and collect duplicates.
-- wantAcked=false -> active (unacknowledged); wantAcked=true -> ignored (acknowledged).
-- Each finding: { label, ackKey, charName }
local function scan(wantAcked)
  local findings = {}
  local acked    = getAcked()
  for _, p in ipairs(ns.db.profiles) do
    if p.encoded then
      local profile = ns.Decode(p.encoded)
      if profile then
        local macroById = {}
        for _, m in ipairs(profile.macros or {}) do macroById[m.id] = m end
        local byKey = {}
        for _, slot in ipairs(profile.slots or {}) do
          local k = actionKey(slot, macroById)
          if k then
            byKey[k] = byKey[k] or {}
            table.insert(byKey[k], slot.id)
          end
        end
        for k, slots in pairs(byKey) do
          if #slots >= 2 then
            local ackKey = p.name .. "|" .. k
            if wantAcked == (acked[ackKey] == true) then
              local slotNames = {}
              for _, id in ipairs(slots) do table.insert(slotNames, slotLabel(id)) end
              table.insert(findings, {
                label    = "[" .. p.name .. "]  " .. actionLabel(k)
                           .. "  --  " .. table.concat(slotNames, ", "),
                ackKey   = ackKey,
                charName = p.char or p.name,
              })
            end
          end
        end
      end
    end
  end
  table.sort(findings, function(a, b) return a.label < b.label end)
  return findings
end

-- Window

local dupeWindow = nil

local function getWindow()
  if dupeWindow then return dupeWindow end

  local f = ui.TitleFrame:new{
    name     = "ABMDupesWindow",
    title    = "Duplicate Actions",
    special  = true,
    level    = 600,
    position = { Center = {}, Width = WIN_W, Height = WIN_H },
  }
  ns.CaptureEscape(f)

  -- Header bar sits between the titlebar and the scroll area.
  -- All header controls are parented to hdrBar so z-ordering is predictable.
  local hdrBar = ui.Frame:new{
    parent   = f,
    position = {
      TopLeft  = { f.titlebar, ui.edge.BottomLeft,  0, 0 },
      TopRight = { f.titlebar, ui.edge.BottomRight, 0, 0 },
      Height   = PAD + BTN_H + PAD,
    },
  }

  local countLabel = ui.Label:new{
    parent  = hdrBar,
    fontObj = "GameFontHighlightSmall",
    position = {
      TopLeft = { hdrBar, ui.edge.TopLeft,
                  PAD + SCAN_W + PAD + CHAR_W + PAD + TOGGL_W + PAD, -PAD },
      Width  = WIN_W - PAD*5 - SCAN_W - CHAR_W - TOGGL_W,
      Height = BTN_H,
    },
  }

  local CONTENT_W = WIN_W - PAD * 2 - 20  -- 20 for scrollbar
  local scroll = ui.ScrollFrame:new{
    parent   = f,
    position = {
      TopLeft     = { hdrBar, ui.edge.BottomLeft,  PAD, 0 },
      BottomRight = { f,      ui.edge.BottomRight, -PAD, PAD + BTN_H + PAD },
    },
  }
  local content = ui.Frame:new{
    parent   = scroll,
    position = { TopLeft = {0, 0}, Width = CONTENT_W },
  }
  scroll:Child(content)

  -- State
  local showIgnored  = false
  local charOptions  = { "All" }
  local charIdx      = 1

  local function rebuildCharOptions()
    local seen = {}
    charOptions = { "All" }
    for _, p in ipairs(ns.db.profiles) do
      local c = p.char or p.name
      if c and not seen[c] then seen[c] = true; table.insert(charOptions, c) end
    end
    if charIdx > #charOptions then charIdx = 1 end
  end

  -- Row pool
  local rows    = {}
  local refresh -- forward-declared; assigned below
  local charBtn -- forward-declared; text updated in refresh

  local function acquireRow(n)
    if rows[n] then return rows[n] end
    local row = {}
    row.rowF = ui.Frame:new{
      parent   = content,
      position = { TopLeft = {0, 0}, Width = CONTENT_W, Height = ROW_H },
    }
    row.label = ui.Label:new{
      parent   = row.rowF,
      fontObj  = "GameFontHighlightSmall",
      position = {
        TopLeft = { row.rowF, ui.edge.TopLeft, 0, 0 },
        Width   = CONTENT_W - ACK_W - PAD,
        Height  = ROW_H,
      },
    }
    row.ackBtn = ui.Button:new{
      parent   = row.rowF,
      template = "UIPanelButtonTemplate",
      glow     = false,
      onClick  = function()
        if not row.currentAckKey then return end
        if showIgnored then
          getAcked()[row.currentAckKey] = nil
        else
          getAcked()[row.currentAckKey] = true
        end
        refresh()
      end,
      position = {
        TopRight = { row.rowF, ui.edge.TopRight, 0, 0 },
        Width    = ACK_W,
        Height   = BTN_H,
      },
    }
    rows[n] = row
    return row
  end

  -- Refresh
  refresh = function()
    rebuildCharOptions()
    charBtn:Text(charOptions[charIdx])
    charBtn:TextAlign("CENTER")

    local findings = scan(showIgnored)

    -- character filter
    local filterChar = charIdx > 1 and charOptions[charIdx]
    if filterChar then
      local filtered = {}
      for _, fd in ipairs(findings) do
        if fd.charName == filterChar then table.insert(filtered, fd) end
      end
      findings = filtered
    end

    local noun = showIgnored and "ignored" or "duplicate"
    countLabel:Text(#findings == 0
      and ("|cff80ff80No " .. noun .. "s.|r")
      or  (#findings .. " " .. noun .. (#findings == 1 and "" or "s") .. " found"))

    local btnLabel = showIgnored and "Un-ignore" or "Ignore"
    for i, fd in ipairs(findings) do
      local row = acquireRow(i)
      row.rowF:TopLeft(content, ui.edge.TopLeft, 0, -(i - 1) * (ROW_H + 2))
      row.label:Text(fd.label)
      row.currentAckKey = fd.ackKey
      row.ackBtn:Text(btnLabel)
      row.ackBtn:TextAlign("CENTER")
      row.rowF:Show()
    end
    for j = #findings + 1, #rows do rows[j].rowF:Hide() end
    content:Height(math.max(#findings * (ROW_H + 2), 1))
  end

  -- Header buttons (parented to hdrBar)
  local function hdrBtn(x, w, label, fn)
    local b = ui.Button:new{
      parent   = hdrBar,
      template = "UIPanelButtonTemplate",
      glow     = false,
      onClick  = fn,
      position = {
        TopLeft = { hdrBar, ui.edge.TopLeft, x, -PAD },
        Width   = w, Height = BTN_H,
      },
    }
    b:Text(label); b:TextAlign("CENTER")
    return b
  end

  hdrBtn(PAD, SCAN_W, "Scan", function() refresh() end)

  charBtn = hdrBtn(PAD + SCAN_W + PAD, CHAR_W, "All", function()
    if charIdx == 1 then
      local me = UnitName("player")
      for i, c in ipairs(charOptions) do
        if c == me then charIdx = i; break end
      end
    else
      charIdx = 1
    end
    refresh()
  end)

  local toggleBtn
  toggleBtn = hdrBtn(PAD + SCAN_W + PAD + CHAR_W + PAD, TOGGL_W, "View Ignored", function()
    showIgnored = not showIgnored
    toggleBtn:Text(showIgnored and "View Active" or "View Ignored")
    toggleBtn:TextAlign("CENTER")
    refresh()
  end)

  local closeBtn = ui.Button:new{
    parent   = f,
    template = "UIPanelButtonTemplate",
    glow     = false,
    onClick  = function() f:Hide() end,
    position = {
      Left   = { f, ui.edge.Center, -30, 0 },
      Bottom = { f, ui.edge.Bottom, 0,   PAD },
      Width  = 60, Height = BTN_H,
    },
  }
  closeBtn:Text("Close"); closeBtn:TextAlign("CENTER")

  f._refresh = refresh
  dupeWindow  = f
  return f
end

ns:registerCommand("dupes", nil, function()
  local w = getWindow()
  w._refresh()
  w:Show()
end, "Scan profiles for duplicate action bar slots")
