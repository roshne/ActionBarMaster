local _, ns = ...

---Build the drag-to-reorder machinery for a row list: a phantom row that
---follows the cursor, a drop-indicator line, and a full-screen catcher that
---ends the drag from anywhere. One instance serves all rows in the grid.
---
---opts:
---  content  LibNUI Frame the rows live in (anchors the drop math)
---  totalW   row width
---  cell     row height (without gap)
---  gap      vertical gap between rows
---  labelX   x offset of the phantom's label
---  labelW   width of the phantom's label
---  count    fun(): number — current number of reorderable rows
---  onDrop   fun(from: integer, insertPos: integer) — called only when the
---           drop actually changes the order
---@param opts table
---@return { Start: fun(orderIdx: integer, label: string), Finish: fun(mouseButton: string) }
function ns.BuildRowDrag(opts)
  local dragFrom = nil  -- 1-based index of the row being dragged
  local dragTo   = nil  -- 0-based gap slot for the drop target
  local rowH     = opts.cell + opts.gap

  -- Drag frames (created once, reused across drags)

  local phantom = CreateFrame("Frame", nil, UIParent)
  phantom:SetSize(opts.totalW, opts.cell)
  phantom:SetFrameStrata("DIALOG")
  phantom:SetFrameLevel(700)
  phantom:EnableMouse(false)
  phantom:Hide()
  local phantomBg = phantom:CreateTexture(nil, "BACKGROUND")
  phantomBg:SetAllPoints()
  phantomBg:SetColorTexture(0.15, 0.35, 0.7, 0.6)
  local phantomLabel = phantom:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  phantomLabel:SetPoint("LEFT", phantom, "LEFT", opts.labelX, 0)
  phantomLabel:SetWidth(opts.labelW)
  phantomLabel:SetJustifyH("RIGHT")

  local dropLine = CreateFrame("Frame", nil, UIParent)
  dropLine:SetSize(opts.totalW, 2)
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

    local contentTop  = opts.content._widget:GetTop()
    local contentLeft = opts.content._widget:GetLeft()
    local n           = opts.count()

    -- Round cursor position to nearest row gap (0 = before first row, n = after last)
    local relY = contentTop - cy
    local slot = math.floor(relY / rowH + 0.5)
    slot  = math.max(0, math.min(n, slot))
    dragTo = slot

    -- Drop indicator line sits at the top of the target gap
    local lineY = contentTop - slot * rowH
    dropLine:ClearAllPoints()
    dropLine:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", contentLeft, lineY)
    dropLine:SetWidth(opts.totalW)
    dropLine:Show()

    -- Phantom row follows cursor, clamped inside content bounds
    local phantomY = cy + opts.cell * 0.5
    phantomY = math.min(contentTop, math.max(contentTop - n * rowH + opts.cell, phantomY))
    phantom:ClearAllPoints()
    phantom:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", contentLeft, phantomY)
    phantom:Show()
  end)

  local function finish(btn)
    local from = dragFrom
    local to   = dragTo
    dragFrom = nil
    dragTo   = nil
    phantom:Hide()
    dropLine:Hide()
    catcher:Hide()

    if btn == "LeftButton" and from and to then
      -- Convert 0-based gap slot to a 1-based insert position in the post-removal array
      local insertPos
      if to <= from - 1 then insertPos = to + 1
      else                   insertPos = to end
      -- Only fire when the order actually changes; a plain click on a drag
      -- handle also lands here with a no-op drop
      if insertPos ~= from then opts.onDrop(from, insertPos) end
    end
  end

  -- WoW Button frames capture the mouse on press, so OnMouseUp always fires on
  -- whichever handle was pressed — not on the catcher. finish is exposed so
  -- either path correctly ends the drag.
  catcher:SetScript("OnMouseUp", function(_, btn) finish(btn) end)

  local function start(orderIdx, label)
    dragFrom = orderIdx
    dragTo   = nil
    phantomLabel:SetText(label)
    catcher:Show()
  end

  return { Start = start, Finish = finish }
end
