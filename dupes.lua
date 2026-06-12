local _, ns = ...
local ui = ns.ui

local WIN_W = 560
local WIN_H = 400
local PAD   = 8
local ROW_H = 22
local ACK_W = 64
local BTN_H = 22

local function getAcked()
  if not ns.db.ackedDupes then ns.db.ackedDupes = {} end
  return ns.db.ackedDupes
end

-- Stable identity key for a slot. Returns nil for ephemeral types that should
-- not be tracked. Macros are keyed by name+body so a re-capture doesn't re-flag.
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

-- Best-effort human-readable label for a key.
local function actionLabel(key)
  local t  = key:match("^([^|]+)|")
  local id = tonumber(key:match("|(%d+)$"))
  if (t == "spell" or t == "racial") and id then
    return GetSpellInfo and GetSpellInfo(id) or key
  end
  if t == "item" and id then
    return GetItemInfo and GetItemInfo(id) or key
  end
  if t == "flyout" and id then
    local name = GetFlyoutInfo and GetFlyoutInfo(id)
    return name and ("Flyout: " .. name) or key
  end
  if t == "summonmount" and id then
    local name = C_MountJournal and C_MountJournal.GetMountInfoByID(id)
    return name and ("Mount: " .. name) or key
  end
  if t == "macro" then
    return "Macro: " .. (key:match("^macro|([^|]+)|") or "?")
  end
  if t == "summonpet" then
    return "Pet: " .. (key:match("|(.-)$") or "?"):sub(1, 10) .. "…"
  end
  return key
end

-- Slot ID → "Bar Label #col"
local function slotLabel(slotID)
  return ns.GetBarLabel(math.ceil(slotID / 12)) .. " #" .. ((slotID - 1) % 12 + 1)
end

-- Decode every profile; return findings not yet acknowledged.
-- Each finding: { label=string, ackKey=string }
local function scanAll()
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
            if not acked[ackKey] then
              local slotNames = {}
              for _, id in ipairs(slots) do
                table.insert(slotNames, slotLabel(id))
              end
              table.insert(findings, {
                label  = "[" .. p.name .. "]  " .. actionLabel(k)
                         .. "  —  " .. table.concat(slotNames, ", "),
                ackKey = ackKey,
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

-- ── Window ────────────────────────────────────────────────────────────────────

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

  local countLabel = ui.Label:new{
    parent   = f,
    fontObj  = "GameFontHighlightSmall",
    position = {
      TopLeft = { f.titlebar, ui.edge.BottomLeft, PAD + 60 + PAD, -PAD },
      Width   = WIN_W - PAD * 4 - 60,
      Height  = BTN_H,
    },
  }

  local CONTENT_W = WIN_W - PAD * 2 - 20  -- 20 for scrollbar
  local scroll = ui.ScrollFrame:new{
    parent   = f,
    position = {
      TopLeft     = { f.titlebar, ui.edge.BottomLeft,  PAD, -(PAD + BTN_H + PAD) },
      BottomRight = { f,          ui.edge.BottomRight, -PAD, PAD + BTN_H + PAD },
    },
  }
  local content = ui.Frame:new{
    parent   = scroll,
    position = { TopLeft = {0, 0}, Width = CONTENT_W },
  }
  scroll:Child(content)

  -- Row pool: Label + Ignore button, re-filled on every refresh.
  local rows   = {}
  local refresh  -- forward-declared; assigned below

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
        if row.currentAckKey then
          getAcked()[row.currentAckKey] = true
          refresh()
        end
      end,
      position = {
        TopRight = { row.rowF, ui.edge.TopRight, 0, 0 },
        Width    = ACK_W,
        Height   = BTN_H,
      },
    }
    row.ackBtn:Text("Ignore")
    row.ackBtn:TextAlign("CENTER")
    rows[n] = row
    return row
  end

  refresh = function()
    local findings = scanAll()
    if #findings == 0 then
      countLabel:Text("|cff80ff80No duplicates found.|r")
    else
      countLabel:Text(#findings .. " duplicate" .. (#findings == 1 and "" or "s") .. " found")
    end
    for i, finding in ipairs(findings) do
      local row = acquireRow(i)
      row.rowF:TopLeft(content, ui.edge.TopLeft, 0, -(i - 1) * (ROW_H + 2))
      row.label:Text(finding.label)
      row.currentAckKey = finding.ackKey
      row.rowF:Show()
    end
    for j = #findings + 1, #rows do rows[j].rowF:Hide() end
    content:Height(math.max(#findings * (ROW_H + 2), 1))
  end

  local scanBtn = ui.Button:new{
    parent   = f,
    template = "UIPanelButtonTemplate",
    glow     = false,
    onClick  = function() refresh() end,
    position = {
      TopLeft = { f.titlebar, ui.edge.BottomLeft, PAD, -PAD },
      Width   = 60,
      Height  = BTN_H,
    },
  }
  scanBtn:Text("Scan")
  scanBtn:TextAlign("CENTER")

  local closeBtn = ui.Button:new{
    parent   = f,
    template = "UIPanelButtonTemplate",
    glow     = false,
    onClick  = function() f:Hide() end,
    position = {
      Left   = { f, ui.edge.Center, -30, 0 },
      Bottom = { f, ui.edge.Bottom, 0,   PAD },
      Width  = 60,
      Height = BTN_H,
    },
  }
  closeBtn:Text("Close")
  closeBtn:TextAlign("CENTER")

  f._refresh = refresh
  dupeWindow  = f
  return f
end

ns:registerCommand("dupes", nil, function()
  local w = getWindow()
  w._refresh()
  w:Show()
end, "Scan profiles for duplicate action bar slots")
