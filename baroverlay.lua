---@class ActionBarMaster
local ns = select(2, ...)

-- On-screen bar labels: while the main window is open, tag each visible action
-- bar with the same "Bar 3" / "Class 2" name the grid shows, so the grid rows
-- can be matched to the physical bars on screen. Purely a decorative overlay —
-- reads button state, never writes it (no taint), and lives only while shown.

local GAP  = 4    -- px between label and the bar edge
local PAD  = 4    -- px padding inside the label background

-- Button discovery + paged-slot reads are the shared, addon-agnostic (LibActionButton
-- → Bartender/Dominos/ElvUI + Blizzard fallback) primitives on ns.wow, so this overlay
-- and LibNAddOn's ns.wow.ReadActionBars() stay one implementation (nazumods/wow#466).
local collectButtons = ns.wow.collectActionButtons
local actionSlot     = ns.wow.actionSlotOf

local container  -- high-strata parent for all labels
local driver     -- event frame; only registered while shown
local labels = {}  -- pooled label frames

local function ensureContainer()
  if container then return end
  container = CreateFrame("Frame", nil, UIParent)
  -- temporary, decorative: sit above the bars (and the ABM window) but below
  -- real tooltips
  container:SetFrameStrata("FULLSCREEN_DIALOG")
  container:SetFrameLevel(1000)
  container:SetAllPoints(UIParent)
end

local function acquireLabel(i)
  local label = labels[i]
  if label then return label end
  label = CreateFrame("Frame", nil, container)
  label.bg = label:CreateTexture(nil, "BACKGROUND")
  label.bg:SetAllPoints()
  label.bg:SetColorTexture(0, 0, 0, 0.7)
  label.text = label:CreateFontString(nil, "OVERLAY")
  local font = GameFontNormal:GetFont()
  label.text:SetFont(font, 16, "OUTLINE")
  label.text:SetTextColor(1, 0.82, 0)  -- gold, matches the ABM window accent
  label.text:SetPoint("CENTER")
  label.text:SetJustifyH("CENTER")     -- centre each line of stacked vertical text
  labels[i] = label
  return label
end

-- Stack a label vertically, one char per line, so it reads top-to-bottom beside
-- a vertical bar. A numeric token (the bar number) stays whole on its own line,
-- separated from the word by a blank line: "Bar 3" -> "B\na\nr\n\n3".
local function stackText(s)
  local parts = {}
  for token in string.gmatch(s, "%S+") do
    if string.match(token, "^%d+$") then
      parts[#parts + 1] = token
    else
      local chars = {}
      for k = 1, #token do chars[k] = string.sub(token, k, k) end
      parts[#parts + 1] = table.concat(chars, "\n")
    end
  end
  return table.concat(parts, "\n\n")
end

-- Set the label text (single-line for horizontal bars, vertically stacked for
-- vertical ones) and size the frame to it.
local function sizeLabel(label, barText, vertical)
  label.text:SetText(vertical and stackText(barText) or barText)
  label:SetWidth(label.text:GetStringWidth() + PAD * 2)
  label:SetHeight(label.text:GetStringHeight() + PAD * 2)
end

-- Anchor the label to its bar's bounding box.
--  · Horizontal bars: to the left of the leftmost button, flipping to the right
--    of the rightmost when the bar hugs the left screen edge.
--  · Vertical bars: a stacked label above the top button (centred on the
--    column), flipping below the bottom button when there's no room at the top.
local function place(label, buttons, barText)
  local minL, maxR, minB, maxT, leftBtn, rightBtn, topBtn, bottomBtn
  for _, b in ipairs(buttons) do
    local l, r, bo, t = b:GetLeft(), b:GetRight(), b:GetBottom(), b:GetTop()
    if l and r and bo and t then
      if not minL or l < minL then minL = l; leftBtn   = b end
      if not maxR or r > maxR then maxR = r; rightBtn  = b end
      if not minB or bo < minB then minB = bo; bottomBtn = b end
      if not maxT or t > maxT then maxT = t; topBtn    = b end
    end
  end
  if not minL then return false end

  local vertical = (maxT - minB) > (maxR - minL)
  sizeLabel(label, barText, vertical)
  label:ClearAllPoints()

  if vertical then
    local topPx    = topBtn:GetTop() * topBtn:GetEffectiveScale()
    local screenPx = UIParent:GetHeight() * UIParent:GetEffectiveScale()
    local needPx   = (label:GetHeight() + GAP) * label:GetEffectiveScale()
    if screenPx - topPx < needPx then
      label:SetPoint("TOP", bottomBtn, "BOTTOM", 0, -GAP)
    else
      label:SetPoint("BOTTOM", topBtn, "TOP", 0, GAP)
    end
  else
    local needPx = (label:GetWidth() + GAP) * label:GetEffectiveScale()
    local leftPx = leftBtn:GetLeft() * leftBtn:GetEffectiveScale()
    if leftPx - needPx < 0 then
      label:SetPoint("LEFT", rightBtn, "RIGHT", GAP, 0)
    else
      label:SetPoint("RIGHT", leftBtn, "LEFT", -GAP, 0)
    end
  end
  return true
end

local function Refresh()
  if not container or not container:IsShown() then return end

  local buttons = collectButtons()

  -- group visible action buttons by abm bar (12 slots per bar, matching capture)
  local groups = {}
  for _, b in ipairs(buttons) do
    if b:IsVisible() then
      local slot = actionSlot(b)
      if slot and slot >= 1 and slot <= 180 then
        local abm = math.floor((slot - 1) / 12) + 1
        local g = groups[abm]
        if not g then g = {}; groups[abm] = g end
        g[#g + 1] = b
      end
    end
  end

  local i = 0
  for abm, buttonsInBar in pairs(groups) do
    i = i + 1
    local label = acquireLabel(i)
    if place(label, buttonsInBar, ns.GetBarLabel(abm)) then
      label:Show()
    else
      label:Hide()
    end
  end
  for j = i + 1, #labels do labels[j]:Hide() end
end

local REFRESH_EVENTS = {
  "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
  "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
}

local function Show()
  ensureContainer()
  container:Show()
  if not driver then
    driver = CreateFrame("Frame")
    -- Coalesce the event storm onto the next frame: a re-page (stance, skyriding,
    -- vehicle) has LibActionButton update its buttons within the same event, so a
    -- synchronous read would catch the pre-swap slots. ns:coalesce fires once, 0ms
    -- (next frame) after the first event, dropping the rest of the burst.
    driver:SetScript("OnEvent", function() ns:coalesce("baroverlay", 0, Refresh) end)
  end
  for _, e in ipairs(REFRESH_EVENTS) do driver:RegisterEvent(e) end
  Refresh()
end

local function Hide()
  if driver then driver:UnregisterAllEvents() end
  if container then container:Hide() end
end

---@class ActionBarMaster
---@field barOverlay { Show: fun(), Hide: fun(), Refresh: fun() }
ns.barOverlay = { Show = Show, Hide = Hide, Refresh = Refresh }
