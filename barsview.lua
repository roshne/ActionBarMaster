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

-- Static bar definitions: ABM slot mapping + WoW display label.
-- abmToBarDef is the lookup used when reconstructing ordered rows from db.barOrder.
local BAR_DEFS = {
  { abm = 1,  label = "1"         },
  { abm = 6,  label = "2"         },
  { abm = 5,  label = "3"         },
  { abm = 3,  label = "4"         },
  { abm = 4,  label = "5"         },
  { abm = 13, label = "6"         },
  { abm = 14, label = "7"         },
  { abm = 15, label = "8"         },
  { abm = 2,  label = "Bonus"     },
  { abm = 7,  label = "Class 1"   },
  { abm = 8,  label = "Class 2"   },
  { abm = 9,  label = "Class 3"   },
  { abm = 10, label = "Class 4"   },
  { abm = 12, label = "Class 5"   },
  { abm = 11, label = "Skyriding" },
}

local abmToBarDef = {}
for _, def in ipairs(BAR_DEFS) do abmToBarDef[def.abm] = def end

local DEFAULT_ORDER = {}
for _, def in ipairs(BAR_DEFS) do DEFAULT_ORDER[#DEFAULT_ORDER + 1] = def.abm end

-- Returns the ordered array of bar defs to display, sourced from db.barOrder.
local function getActiveOrder()
  local source = (ns.db and ns.db.barOrder) or DEFAULT_ORDER
  local result = {}
  for _, abm in ipairs(source) do
    local def = abmToBarDef[abm]
    if def then result[#result + 1] = def end
  end
  return result
end

---Build a scrollable action-bar icon grid inside `parent`.
---Rows follow the user-configured order stored in db.barOrder; dragging a row
---label reorders it and persists the new order immediately.
---@return { Update: fun(profile: table?), GetChecked: fun(): table }
function ns.BuildBarsGrid(parent)
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

  local rowFrames      = {}
  local checked        = {}   -- [abmBar | "pet"] = bool; nil means default (checked)
  local currentProfile = nil
  local dragFrom       = nil  -- 1-based index in db.barOrder being dragged
  local dragTo         = nil  -- 0-based gap slot for the drop target
  local Update                -- forward-declared; assigned below

  local function isChecked(key) return checked[key] ~= false end

  -- ── Drag frames (created once, reused across drags) ───────────────────────

  local phantom = CreateFrame("Frame", nil, UIParent)
  phantom:SetSize(totalW, CELL)
  phantom:SetFrameStrata("DIALOG")
  phantom:SetFrameLevel(700)
  phantom:EnableMouse(false)
  phantom:Hide()
  local phantomBg = phantom:CreateTexture(nil, "BACKGROUND")
  phantomBg:SetAllPoints()
  phantomBg:SetColorTexture(0.15, 0.35, 0.7, 0.6)
  local phantomLabel = phantom:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  phantomLabel:SetPoint("LEFT", phantom, "LEFT", GRID_X, 0)
  phantomLabel:SetWidth(LABEL_W)
  phantomLabel:SetJustifyH("RIGHT")

  local dropLine = CreateFrame("Frame", nil, UIParent)
  dropLine:SetSize(totalW, 2)
  dropLine:SetFrameStrata("DIALOG")
  dropLine:SetFrameLevel(699)
  dropLine:EnableMouse(false)
  dropLine:Hide()
  local dropLineTex = dropLine:CreateTexture(nil, "OVERLAY")
  dropLineTex:SetAllPoints()
  dropLineTex:SetColorTexture(1, 0.8, 0, 1)

  -- Full-screen catcher intercepts OnMouseUp to end the drag from anywhere.
  -- Same strata as phantom so frame-level ordering applies.
  local catcher = CreateFrame("Frame", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("DIALOG")
  catcher:SetFrameLevel(698)
  catcher:EnableMouse(true)
  catcher:Hide()

  catcher:SetScript("OnUpdate", function()
    if not dragFrom then return end
    local scale = UIParent:GetEffectiveScale()
    local _, cy = GetCursorPosition()
    cy = cy / scale

    local contentTop  = content._widget:GetTop()
    local contentLeft = content._widget:GetLeft()
    local rowH        = CELL + GAP
    local n           = #(ns.db.barOrder)

    -- Round cursor position to nearest row gap (0 = before first row, n = after last)
    local relY = contentTop - cy
    local slot = math.floor(relY / rowH + 0.5)
    slot  = math.max(0, math.min(n, slot))
    dragTo = slot

    -- Drop indicator line sits at the top of the target gap
    local lineY = contentTop - slot * rowH
    dropLine:ClearAllPoints()
    dropLine:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", contentLeft, lineY)
    dropLine:SetWidth(totalW)
    dropLine:Show()

    -- Phantom row follows cursor, clamped inside content bounds
    local phantomY = cy + CELL * 0.5
    phantomY = math.min(contentTop, math.max(contentTop - n * rowH + CELL, phantomY))
    phantom:ClearAllPoints()
    phantom:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", contentLeft, phantomY)
    phantom:Show()
  end)

  catcher:SetScript("OnMouseUp", function(_, btn)
    local from = dragFrom
    local to   = dragTo
    dragFrom = nil
    dragTo   = nil
    phantom:Hide()
    dropLine:Hide()
    catcher:Hide()

    if btn == "LeftButton" and from and to then
      -- Convert gap slot to a 1-based insert position in the post-removal array
      local insertPos
      if to <= from - 1 then insertPos = to + 1
      else                   insertPos = to end
      if insertPos ~= from then
        local order = ns.db.barOrder
        local moved = table.remove(order, from)
        table.insert(order, insertPos, moved)
      end
    end

    if currentProfile then Update(currentProfile) end
  end)

  -- ── Update ────────────────────────────────────────────────────────────────

  Update = function(profile)
    currentProfile = profile
    for _, fr in ipairs(rowFrames) do fr:Hide() end
    rowFrames = {}

    if not (profile and profile.slots) then
      content:Height(1)
      return
    end

    local macros        = profile.macros or {}
    local getIcon       = ns._bar_getIcon
    local getPetIcon    = ns._bar_getPetIcon
    local addTooltip    = ns._bar_addTooltip
    local addPetTooltip = ns._bar_addPetTooltip

    local slotMap = {}
    for _, entry in ipairs(profile.slots) do
      local bar = math.floor((entry.id - 1) / NCOLS) + 1
      local col = ((entry.id - 1) % NCOLS) + 1
      if bar >= 1 and bar <= NBARS then
        if not slotMap[bar] then slotMap[bar] = {} end
        slotMap[bar][col] = entry
      end
    end

    local activeOrder = getActiveOrder()
    local totalRows   = 0

    for rowIdx, barDef in ipairs(activeOrder) do
      local y = totalRows * (CELL + GAP)

      local rowF = ui.Frame:new{
        parent   = content,
        position = {
          TopLeft = { content, ui.edge.TopLeft, 0, -y },
          Width   = totalW,
          Height  = CELL,
        },
      }
      rowFrames[#rowFrames + 1] = rowF

      -- Transparent drag handle overlaying the label area; clicking initiates drag
      local capturedIdx = rowIdx
      local capturedLabel = barDef.label
      local handle = ui.Button:new{
        parent   = rowF,
        template = "", glow = false,
        position = {
          TopLeft = { rowF, ui.edge.TopLeft, GRID_X, 0 },
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
      handle:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        dragFrom = capturedIdx
        dragTo   = nil
        phantomLabel:SetText(capturedLabel)
        catcher:Show()
      end)

      -- Checkbox
      local barKey = barDef.abm
      local chk = ui.CheckButton:new{
        parent   = rowF,
        position = { TopLeft = { rowF, ui.edge.TopLeft, CHK_X, CHK_Y }, Width = CHK_SZ, Height = CHK_SZ },
        OnToggle = function(self) checked[barKey] = self:Checked() end,
      }
      chk:Checked(isChecked(barKey))

      -- Bar label (rendered under the transparent handle button)
      ui.Label:new{
        parent = rowF, text = barDef.label, justifyH = "RIGHT",
        fontObj = "GameFontHighlightSmall",
        position = { TopLeft = { rowF, ui.edge.TopLeft, GRID_X, 0 }, Width = LABEL_W, Height = CELL },
      }

      -- Slot cells
      for col = 1, NCOLS do
        local x = GRID_X + LABEL_W + GAP + (col - 1) * (CELL + GAP)

        ui.Texture:new{
          parent = rowF, color = rgba(255, 255, 255, 0.05),
          position = { TopLeft = { rowF, ui.edge.TopLeft, x, 0 }, Width = CELL, Height = CELL },
        }

        local labelParent = rowF
        local labelOffX   = x + 2
        local labelOffY   = -1

        local slotID = (barDef.abm - 1) * NCOLS + col
        local entry  = slotMap[barDef.abm] and slotMap[barDef.abm][col]
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
            labelParent = cellBtn
            labelOffX   = 4
            labelOffY   = -4
          end
        end

        ui.Label:new{
          parent = labelParent, text = tostring(slotID), justifyH = "LEFT",
          fontObj = "GameFontHighlightSmall",
          position = { TopLeft = { labelParent, ui.edge.TopLeft, labelOffX, labelOffY }, Width = 20, Height = 10 },
        }
      end

      totalRows = totalRows + 1
    end

    -- Pet bar: always at bottom, not user-reorderable
    local petslots = profile.petslots
    if petslots and #petslots > 0 then
      local y = totalRows * (CELL + GAP)
      local rowF = ui.Frame:new{
        parent   = content,
        position = {
          TopLeft = { content, ui.edge.TopLeft, 0, -y },
          Width   = totalW, Height = CELL,
        },
      }
      rowFrames[#rowFrames + 1] = rowF

      local petChk = ui.CheckButton:new{
        parent   = rowF,
        position = { TopLeft = { rowF, ui.edge.TopLeft, CHK_X, CHK_Y }, Width = CHK_SZ, Height = CHK_SZ },
        OnToggle = function(self) checked.pet = self:Checked() end,
      }
      petChk:Checked(isChecked("pet"))

      ui.Label:new{
        parent = rowF, text = "Pet Bar", justifyH = "RIGHT",
        fontObj = "GameFontHighlightSmall",
        position = { TopLeft = { rowF, ui.edge.TopLeft, GRID_X, 0 }, Width = LABEL_W, Height = CELL },
      }

      local petMap = {}
      for _, entry in ipairs(petslots) do petMap[entry.id] = entry end

      for col = 1, NUM_PET_SLOTS do
        local x = GRID_X + LABEL_W + GAP + (col - 1) * (CELL + GAP)
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

      totalRows = totalRows + 1
    end

    content:Height(math.max(totalRows * (CELL + GAP), 1))
  end

  return { Update = Update, GetChecked = function() return checked end }
end
