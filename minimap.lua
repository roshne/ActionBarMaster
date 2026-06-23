local _, ns = ...

local ICON          = "Interface\\AddOns\\ActionBarMaster\\textures\\minimap.png"
local DEFAULT_ANGLE = 198  -- degrees around the ring (lower-left, clear of default UI)

local button  -- created lazily on first show

-- Place the button on the minimap ring at the saved angle (round minimap).
local function UpdatePosition()
  local angle  = math.rad(ns.db.minimap.angle)
  local radius = (Minimap:GetWidth() / 2) + 8
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
end

-- While dragging, follow the cursor's angle around the minimap centre.
local function DragUpdate()
  local mx, my = Minimap:GetCenter()
  local scale  = Minimap:GetEffectiveScale()
  local px, py = GetCursorPosition()
  px, py = px / scale, py / scale
  ns.db.minimap.angle = math.deg(math.atan2(py - my, px - mx))
  UpdatePosition()
end

local function ShowMenu()
  MenuUtil.CreateContextMenu(button, function(_, root)
    root:CreateTitle("Action Bar Master")
    root:CreateButton("Open", function() ns:Open() end)
    root:CreateButton("Hide minimap button", function() ns.SetMinimapShown(false) end)
  end)
end

local function CreateButton()
  local b = CreateFrame("Button", "ActionBarMasterMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b:SetMovable(true)

  -- The medallion art carries its own stone border, so the icon fills the
  -- button and no separate ring overlay is needed.
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(b)
  icon:SetTexture(ICON)
  b.icon = icon

  -- Button:SetHighlightTexture defaults to ADD blend, so the glow brightens the
  -- icon on hover instead of painting over it (a plain HIGHLIGHT-layer texture
  -- defaults to BLEND and would hide the icon).
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", DragUpdate) end)
  b:SetScript("OnDragStop",  function(self) self:SetScript("OnUpdate", nil) end)

  b:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      if IsShiftKeyDown() then ShowMenu() else ns:ToggleMainWindow() end
    end
    -- LeftButton: reserved (nothing for now)
  end)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Action Bar Master")
    GameTooltip:AddLine("Right-click to open", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift-right-click for menu", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return b
end

---Show or hide the minimap button and persist the choice. Builds the button
---lazily on first show so a hidden default never creates a frame.
---@param show boolean
function ns.SetMinimapShown(show)
  ns.db.minimap.hide = not show
  if not button then
    if not show then return end
    button = CreateButton()
  end
  if show then
    button:Show()
    UpdatePosition()
  else
    button:Hide()
  end
end

ns:registerCommand("minimap", nil, function()
  ns.SetMinimapShown(ns.db.minimap.hide)  -- toggle from current state
  ns.Print(ns.db.minimap.hide and "Minimap button hidden." or "Minimap button shown.")
end, "Toggle the minimap button")

ns:registerEvent("PLAYER_LOGIN", function()
  -- lazy-init (no DB version bump); mirrors db.ackedDupes
  ns.db.minimap = ns.db.minimap or {}
  if ns.db.minimap.angle == nil then ns.db.minimap.angle = DEFAULT_ANGLE end
  ns.SetMinimapShown(not ns.db.minimap.hide)
end)
