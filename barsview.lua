local _, ns = ...
local ui   = ns.ui
local rgba = ns.Colors.rgba

local CELL          = 38
local LABEL_W       = 56
local GAP           = 2
local HDR_H         = 18
local NCOLS         = 12
local NBARS         = 15
local NUM_PET_SLOTS = 10
local CHK_SZ        = 20
local CHK_X         = 4
local CHK_Y         = -math.floor((CELL - CHK_SZ) / 2)
local CHK_W         = CHK_X + CHK_SZ + 2
local GRID_X        = CHK_W + GAP

---Build a scrollable action-bar icon grid inside `parent`.
---Rows follow the user-configured order stored in db.barOrder; dragging a row
---label reorders it and persists the new order immediately.
---@return { Update: fun(profile: table?), GetChecked: fun(): table }
function ns.BuildBarsGrid(parent)
  local getIcon       = ns._bar_getIcon
  local getPetIcon    = ns._bar_getPetIcon
  local addTooltip    = ns._bar_addTooltip
  local addPetTooltip = ns._bar_addPetTooltip

  local totalW = GRID_X + LABEL_W + GAP + NCOLS * CELL + (NCOLS - 1) * GAP

  -- Column headers pinned above the scroll area, always visible
  local hdrF = ui.Frame:new{
    parent   = parent,
    position = { TopLeft = { parent, ui.edge.TopLeft, 0, 0 }, Width = totalW, Height = HDR_H },
  }
  for col = 1, NCOLS do
    local x = GRID_X + LABEL_W + GAP + (col - 1) * (CELL + GAP)
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

  local barRows        = {}   -- pooled bar rows, re-filled on every Update
  local petRow         = nil  -- pooled pet bar row
  local checked        = {}   -- [abmBar | "pet"] = bool; nil means default (checked)
  local currentProfile = nil
  local Update                -- forward-declared; assigned below

  local function isChecked(key) return checked[key] ~= false end

  local drag = ns.BuildRowDrag{
    content = content,
    totalW  = totalW,
    cell    = CELL,
    gap     = GAP,
    labelX  = GRID_X,
    labelW  = LABEL_W,
    count   = function() return #(ns.db.barOrder) end,
    onDrop  = function(from, insertPos)
      local order = ns.db.barOrder
      local moved = table.remove(order, from)
      table.insert(order, insertPos, moved)
      if currentProfile then Update(currentProfile) end
    end,
  }

  -- ── Row pool ───────────────────────────────────────────────────────────────
  -- Rows and cells are created once and re-filled on every Update — WoW frames
  -- are never garbage-collected, so recreating them leaks memory each refresh.

  local function acquireBarRow(n)
    if barRows[n] then return barRows[n] end
    local row = {}  -- fill sets: orderIdx, barLabel, barKey
    row.rowF = ui.Frame:new{
      parent   = content,
      position = {
        TopLeft = { content, ui.edge.TopLeft, 0, 0 },
        Width   = totalW,
        Height  = CELL,
      },
    }

    -- Transparent drag handle overlaying the label area; clicking initiates drag
    local handle = ui.Button:new{
      parent   = row.rowF,
      template = "", glow = false,
      position = {
        TopLeft = { row.rowF, ui.edge.TopLeft, GRID_X, 0 },
        Width   = LABEL_W, Height = CELL,
      },
      onClick = function() end,
    }
    handle:SetScript("OnEnter", function()
      GameTooltip:SetOwner(handle._widget, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Drag to reorder", 1, 1, 1)
      GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    handle:SetScript("OnMouseDown", function(_, mbtn)
      if mbtn ~= "LeftButton" then return end
      drag.Start(row.orderIdx, row.barLabel)
    end)
    handle:SetScript("OnMouseUp", function(_, mbtn) drag.Finish(mbtn) end)

    -- Hamburger grip: three stacked lines signalling the row is draggable.
    -- Drawn with textures (vertically centered in the cell) rather than an
    -- atlas — the only stock drag-grip atlas is glue-screen-only.
    for line = 0, 2 do
      ui.Texture:new{
        parent   = handle,
        color    = rgba(255, 255, 255, 0.35),
        position = {
          TopLeft = { handle, ui.edge.TopLeft, 2, -(CELL - 8) / 2 - line * 3 },
          Width   = 10,
          Height  = 2,
        },
      }
    end

    row.chk = ui.CheckButton:new{
      parent   = row.rowF,
      position = { TopLeft = { row.rowF, ui.edge.TopLeft, CHK_X, CHK_Y }, Width = CHK_SZ, Height = CHK_SZ },
      OnToggle = function(self) checked[row.barKey] = self:Checked() end,
    }

    -- Bar label (rendered under the transparent handle button)
    row.label = ui.Label:new{
      parent = row.rowF, justifyH = "RIGHT",
      fontObj = "GameFontHighlightSmall",
      position = { TopLeft = { row.rowF, ui.edge.TopLeft, GRID_X, 0 }, Width = LABEL_W, Height = CELL },
    }

    row.cells = {}
    for col = 1, NCOLS do
      local x = GRID_X + LABEL_W + GAP + (col - 1) * (CELL + GAP)
      ui.Texture:new{
        parent = row.rowF, color = rgba(255, 255, 255, 0.05),
        position = { TopLeft = { row.rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
      }
      local btn = ui.Button:new{
        parent = row.rowF, template = "", glow = false,
        position = { TopLeft = { row.rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
      }
      local icon = ui.Texture:new{
        parent   = btn,
        position = { TopLeft = { btn, ui.edge.TopLeft, 1, -1 }, Width = CELL - 2, Height = CELL - 2, Hide = true },
      }
      local num = ui.Label:new{
        parent = btn, justifyH = "LEFT",
        fontObj = "GameFontHighlightSmall",
        position = { TopLeft = { btn, ui.edge.TopLeft, 2, -1 }, Width = 20, Height = 10 },
      }
      row.cells[col] = { btn = btn, icon = icon, num = num }
    end

    barRows[n] = row
    return row
  end

  -- Placeholder for entries the viewing character can't resolve (professions it
  -- hasn't learned, uncached items, ...). A bundled texture, NOT
  -- INV_Misc_QuestionMark — the game assigns that icon to outfits it has no icon
  -- for, so it would be indistinguishable from a real outfit entry in the grid.
  local UNRESOLVED_TEX = "Interface\\AddOns\\ActionBarMaster\\textures\\unresolved"

  local function fillCell(cell, slotID, entry, macros)
    -- unresolvable entries still occupy the slot: show the placeholder and
    -- keep the tooltip (which has per-type text fallbacks) instead of blank
    local icon = entry and (getIcon(entry, macros) or UNRESOLVED_TEX)
    if icon then
      cell.icon:Texture(icon)
      cell.icon:Show()
      addTooltip(cell.btn, entry, macros)
      cell.num:TopLeft(cell.btn, ui.edge.TopLeft, 4, -4)
    else
      cell.icon:Hide()
      cell.btn:SetScript("OnEnter", nil)
      cell.btn:SetScript("OnLeave", nil)
      cell.num:TopLeft(cell.btn, ui.edge.TopLeft, 2, -1)
    end
    cell.num:Text(tostring(slotID))
  end

  local function acquirePetRow()
    if petRow then return petRow end
    petRow = {}
    petRow.rowF = ui.Frame:new{
      parent   = content,
      position = {
        TopLeft = { content, ui.edge.TopLeft, 0, 0 },
        Width   = totalW,
        Height  = CELL,
      },
    }
    petRow.chk = ui.CheckButton:new{
      parent   = petRow.rowF,
      position = { TopLeft = { petRow.rowF, ui.edge.TopLeft, CHK_X, CHK_Y }, Width = CHK_SZ, Height = CHK_SZ },
      OnToggle = function(self) checked.pet = self:Checked() end,
    }
    ui.Label:new{
      parent = petRow.rowF, text = "Pet Bar", justifyH = "RIGHT",
      fontObj = "GameFontHighlightSmall",
      position = { TopLeft = { petRow.rowF, ui.edge.TopLeft, GRID_X, 0 }, Width = LABEL_W, Height = CELL },
    }
    petRow.cells = {}
    for col = 1, NUM_PET_SLOTS do
      local x = GRID_X + LABEL_W + GAP + (col - 1) * (CELL + GAP)
      ui.Texture:new{
        parent = petRow.rowF, color = rgba(255, 255, 255, 0.05),
        position = { TopLeft = { petRow.rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
      }
      local btn = ui.Button:new{
        parent = petRow.rowF, template = "", glow = false,
        position = { TopLeft = { petRow.rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
      }
      local icon = ui.Texture:new{
        parent   = btn,
        position = { TopLeft = { btn, ui.edge.TopLeft, 1, -1 }, Width = CELL - 2, Height = CELL - 2, Hide = true },
      }
      petRow.cells[col] = { btn = btn, icon = icon }
    end
    return petRow
  end

  local function fillPetCell(cell, entry)
    local icon = entry and (getPetIcon(entry) or UNRESOLVED_TEX)
    if icon then
      cell.icon:Texture(icon)
      cell.icon:Show()
      addPetTooltip(cell.btn, entry)
    else
      cell.icon:Hide()
      cell.btn:SetScript("OnEnter", nil)
      cell.btn:SetScript("OnLeave", nil)
    end
  end

  -- ── Update ────────────────────────────────────────────────────────────────

  Update = function(profile)
    currentProfile = profile

    if not (profile and profile.slots) then
      for _, row in ipairs(barRows) do row.rowF:Hide() end
      if petRow then petRow.rowF:Hide() end
      content:Height(1)
      return
    end

    local macros = profile.macros or {}

    local slotMap = {}
    for _, entry in ipairs(profile.slots) do
      local bar = math.floor((entry.id - 1) / NCOLS) + 1
      local col = ((entry.id - 1) % NCOLS) + 1
      if bar >= 1 and bar <= NBARS then
        if not slotMap[bar] then slotMap[bar] = {} end
        slotMap[bar][col] = entry
      end
    end

    local activeOrder = ns.GetActiveBarOrder()
    local totalRows   = 0

    for rowIdx, barDef in ipairs(activeOrder) do
      local row = acquireBarRow(rowIdx)
      row.orderIdx = rowIdx
      row.barLabel = barDef.label
      row.barKey   = barDef.abm
      row.rowF:TopLeft(content, ui.edge.TopLeft, 0, -totalRows * (CELL + GAP))
      row.label:Text(barDef.label)
      row.chk:Checked(isChecked(barDef.abm))
      for col = 1, NCOLS do
        fillCell(row.cells[col], (barDef.abm - 1) * NCOLS + col,
          slotMap[barDef.abm] and slotMap[barDef.abm][col], macros)
      end
      row.rowF:Show()
      totalRows = totalRows + 1
    end
    for j = #activeOrder + 1, #barRows do barRows[j].rowF:Hide() end

    -- Pet bar: always at bottom, not user-reorderable
    local petslots = profile.petslots
    if petslots and #petslots > 0 then
      local row = acquirePetRow()
      row.rowF:TopLeft(content, ui.edge.TopLeft, 0, -totalRows * (CELL + GAP))
      row.chk:Checked(isChecked("pet"))
      local petMap = {}
      for _, entry in ipairs(petslots) do petMap[entry.id] = entry end
      for col = 1, NUM_PET_SLOTS do
        fillPetCell(row.cells[col], petMap[col])
      end
      row.rowF:Show()
      totalRows = totalRows + 1
    elseif petRow then
      petRow.rowF:Hide()
    end

    content:Height(math.max(totalRows * (CELL + GAP), 1))
  end

  return { Update = Update, GetChecked = function() return checked end }
end
