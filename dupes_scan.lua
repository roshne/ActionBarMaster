local _, ns = ...

-- Duplicate-action scan + labelling, split out of dupes.lua (file-size cap).
-- The window (dupes.lua) consumes ns.ScanDupes / ns.GetAckedDupes.
function ns.GetAckedDupes()
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
function ns.ScanDupes(wantAcked)
  local findings = {}
  local acked    = ns.GetAckedDupes()
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
                label       = "[" .. p.name .. "]  " .. actionLabel(k)
                              .. "  --  " .. table.concat(slotNames, ", "),
                ackKey      = ackKey,
                charName    = p.char or p.name,
                slotIDs     = slots,
                actionName  = actionLabel(k),
                profileName = p.name,
                profile     = p,
                spec        = p.spec or "",
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
