local _, ns = ...
local ui   = ns.ui
local rgba = ns.Colors.rgba

local CELL          = 34
local LABEL_W       = 24
local GAP           = 2
local HDR_H         = 18
local NCOLS         = 12
local NBARS         = 15
local NUM_PET_SLOTS = 10

local function spellTex(id)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  return GetSpellTexture(id)
end

local function getIcon(entry, macros)
  local t = entry.type
  if t == "spell" or t == "racial" then
    return spellTex(entry.index)
  elseif t == "profession" then
    local spellID = ns.GetProfessionSpellID(entry.index, entry.profSlot)
    if not spellID and entry.strindex then
      local info = ns.GetProfessionNameMap()[entry.strindex]
      if info then spellID = ns.GetProfessionSpellID(info.ordinal, info.slot) end
    end
    if spellID then return spellTex(spellID) end
  elseif t == "macro" then
    for _, m in ipairs(macros) do
      if m.id == entry.index then
        local ic = m.icon or "INV_Misc_QuestionMark"
        local n = tonumber(ic)
        if n then return n end  -- modern WoW returns a numeric fileID
        if not ic:find("\\") and not ic:find("/") then
          return "Interface\\Icons\\" .. ic
        end
        return ic
      end
    end
  elseif t == "item" then
    return GetItemIcon(entry.index)
  elseif t == "summonmount" then
    local _, _, icon = C_MountJournal.GetMountInfoByID(entry.index)
    return icon
  elseif t == "equipmentset" then
    local ids = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs()
    local setID = ids and ids[entry.index]
    if setID then
      local _, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
      return icon
    end
  end
end

local function getPetIcon(entry)
  if entry.type == "spell" then return spellTex(entry.index) end
  -- token pet commands (Attack, Follow, Stay, etc.): position 2 is a global-string key
  -- (e.g. "PETACTIONBUTTONATTACK"), not a direct path. Blizzard resolves it via
  -- _G[texture] — see PetActionBar.lua:130.
  local _, texture = GetPetActionInfo(entry.id)
  return texture and _G[texture]
end

-- Overlay a transparent mouse-catching Button on a filled cell and wire up GameTooltip.
-- SetScript replaces the registered OnEnter/OnLeave; with glow=false Button:OnEnter is a no-op.
local function addTooltip(btn, entry, macros)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn._widget, "ANCHOR_TOPRIGHT", -2, 0)
    local t = entry.type
    if t == "spell" or t == "racial" then
      GameTooltip:SetSpellByID(entry.index)
    elseif t == "profession" then
      local sid = ns.GetProfessionSpellID(entry.index, entry.profSlot)
      if not sid and entry.strindex then
        local info = ns.GetProfessionNameMap()[entry.strindex]
        if info then sid = ns.GetProfessionSpellID(info.ordinal, info.slot) end
      end
      if sid then GameTooltip:SetSpellByID(sid)
      else GameTooltip:AddLine(entry.strindex or "?", 1, 1, 1) end
    elseif t == "macro" then
      for _, m in ipairs(macros) do
        if m.id == entry.index then
          GameTooltip:AddLine(m.name or "?", 1, 1, 1); break
        end
      end
    elseif t == "item" then
      GameTooltip:SetHyperlink("item:" .. entry.index)
    elseif t == "summonmount" then
      local _, spellID = C_MountJournal.GetMountInfoByID(entry.index)
      if spellID then GameTooltip:SetSpellByID(spellID) end
    elseif t == "equipmentset" then
      local ids = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs()
      local setID = ids and ids[entry.index]
      local name = setID and C_EquipmentSet.GetEquipmentSetInfo(setID) or "Equipment Set"
      GameTooltip:AddLine(name, 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function addPetTooltip(btn, entry)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn._widget, "ANCHOR_TOPRIGHT", -2, 0)
    if entry.type == "spell" then
      GameTooltip:SetSpellByID(entry.index)
    else
      local _, _, _, _, _, _, spellID = GetPetActionInfo(entry.id)
      if spellID and spellID > 0 then
        GameTooltip:SetSpellByID(spellID)
      elseif entry.strindex then
        GameTooltip:AddLine(entry.strindex, 1, 1, 1)
      end
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---Build a scrollable action-bar icon grid inside `parent`.
---Row per bar 1–maxBar (numbered on left), column per slot ordinal (1–12 across top).
---@return { Update: fun(profile: table?) }
function ns.BuildBarsGrid(parent)
  -- totalW = 24 + 2 + 12*34 + 11*2 = 456
  local totalW = LABEL_W + GAP + NCOLS * CELL + (NCOLS - 1) * GAP

  -- column headers pinned above the scroll area, always visible
  local hdrF = ui.Frame:new{
    parent   = parent,
    position = { TopLeft = { parent, ui.edge.TopLeft, 0, 0 }, Width = totalW, Height = HDR_H },
  }
  for col = 1, NCOLS do
    local x = LABEL_W + GAP + (col - 1) * (CELL + GAP)
    ui.Label:new{
      parent = hdrF, text = tostring(col), justifyH = "CENTER",
      position = { TopLeft = { hdrF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = HDR_H },
    }
  end

  local scroll = ui.ScrollFrame:new{
    parent   = parent,
    position = {
      TopLeft     = { parent, ui.edge.TopLeft,     0, -HDR_H },
      BottomRight = { parent, ui.edge.BottomRight, 0,  0     },
    },
  }

  local content = ui.Frame:new{
    parent   = scroll,
    position = { TopLeft = { scroll, ui.edge.TopLeft, 0, 0 }, Width = totalW },
  }
  scroll:Child(content)

  local rowFrames = {}

  local function Update(profile)
    for _, fr in ipairs(rowFrames) do fr:Hide() end
    rowFrames = {}

    if not (profile and profile.slots) then
      content:Height(1)
      return
    end

    local macros  = profile.macros or {}
    local slotMap = {}
    local maxBar  = 0

    for _, entry in ipairs(profile.slots) do
      local bar = math.floor((entry.id - 1) / NCOLS) + 1
      local col = ((entry.id - 1) % NCOLS) + 1
      if bar >= 1 and bar <= NBARS then
        if not slotMap[bar] then slotMap[bar] = {} end
        slotMap[bar][col] = entry
        if bar > maxBar then maxBar = bar end
      end
    end

    -- show bars 1–maxBar as sub-frames so the scroll frame handles them correctly;
    -- empty bars between filled ones still get a row so the layout is contiguous
    for bar = 1, maxBar do
      local y = (bar - 1) * (CELL + GAP)

      local rowF = ui.Frame:new{
        parent   = content,
        position = {
          TopLeft = { content, ui.edge.TopLeft, 0, -y },
          Width   = totalW,
          Height  = CELL,
        },
      }
      rowFrames[#rowFrames + 1] = rowF

      ui.Label:new{
        parent = rowF, text = tostring(bar), justifyH = "RIGHT",
        position = { TopLeft = { rowF, ui.edge.TopLeft, 0, 0 }, Width = LABEL_W, Height = CELL },
      }

      for col = 1, NCOLS do
        local x = LABEL_W + GAP + (col - 1) * (CELL + GAP)

        ui.Texture:new{
          parent = rowF, color = rgba(255, 255, 255, 0.05),
          position = { TopLeft = { rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
        }

        local entry = slotMap[bar] and slotMap[bar][col]
        if entry then
          local icon = getIcon(entry, macros)
          if icon then
            local cellBtn = ui.Button:new{
              parent = rowF, template = "", glow = false,
              position = { TopLeft = { rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
            }
            ui.Texture:new{
              parent = cellBtn, path = icon,
              position = { TopLeft = { cellBtn, ui.edge.TopLeft, 1, -1 }, Width = CELL - 2, Height = CELL - 2 },
            }
            addTooltip(cellBtn, entry, macros)
          end
        end
      end
    end

    local totalRows = maxBar

    local petslots = profile.petslots
    if petslots and #petslots > 0 then
      totalRows = totalRows + 1
      local y = maxBar * (CELL + GAP)

      local rowF = ui.Frame:new{
        parent   = content,
        position = {
          TopLeft = { content, ui.edge.TopLeft, 0, -y },
          Width   = totalW,
          Height  = CELL,
        },
      }
      rowFrames[#rowFrames + 1] = rowF

      ui.Label:new{
        parent = rowF, text = "Pet", justifyH = "RIGHT",
        position = { TopLeft = { rowF, ui.edge.TopLeft, 0, 0 }, Width = LABEL_W, Height = CELL },
      }

      local petMap = {}
      for _, entry in ipairs(petslots) do petMap[entry.id] = entry end

      for col = 1, NUM_PET_SLOTS do
        local x = LABEL_W + GAP + (col - 1) * (CELL + GAP)

        ui.Texture:new{
          parent = rowF, color = rgba(255, 255, 255, 0.05),
          position = { TopLeft = { rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
        }

        local entry = petMap[col]
        if entry then
          local icon = getPetIcon(entry)
          if icon then
            local cellBtn = ui.Button:new{
              parent = rowF, template = "", glow = false,
              position = { TopLeft = { rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
            }
            ui.Texture:new{
              parent = cellBtn, path = icon,
              position = { TopLeft = { cellBtn, ui.edge.TopLeft, 1, -1 }, Width = CELL - 2, Height = CELL - 2 },
            }
            addPetTooltip(cellBtn, entry)
          end
        end
      end
    end

    content:Height(math.max(totalRows * (CELL + GAP), 1))
  end

  return { Update = Update }
end
