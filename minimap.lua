local _, ns = ...

local ICON          = "Interface\\AddOns\\ActionBarMaster\\textures\\minimap.png"
local DEFAULT_ANGLE = 198  -- degrees around the ring (lower-left, clear of default UI)

local button  -- created lazily on first show

-- Per-quadrant "is this corner rounded?" flags keyed by GetMinimapShape(), so
-- the button hugs the edge of square / partial minimaps too (matches the
-- LibDBIcon-1.0 table that most addons use). Quadrant order matches the sign
-- checks in UpdatePosition.
local MINIMAP_SHAPES = {
  ["ROUND"]                 = { true,  true,  true,  true  },
  ["SQUARE"]                = { false, false, false, false },
  ["CORNER-TOPLEFT"]        = { false, false, false, true  },
  ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
  ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
  ["CORNER-BOTTOMRIGHT"]    = { true,  false, false, false },
  ["SIDE-LEFT"]             = { false, true,  false, true  },
  ["SIDE-RIGHT"]            = { true,  false, true,  false },
  ["SIDE-TOP"]              = { false, false, true,  true  },
  ["SIDE-BOTTOM"]           = { true,  true,  false, false },
  ["TRICORNER-TOPLEFT"]     = { false, true,  true,  true  },
  ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true  },
  ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true  },
  ["TRICORNER-BOTTOMRIGHT"] = { true,  true,  true,  false },
}

-- Place the button on the minimap edge at the saved angle. Shape-aware: on a
-- round quadrant it sits on the circle; on a square one it clamps to the edge.
local function UpdatePosition()
  local angle = math.rad(ns.db.minimap.angle)
  local x, y = math.cos(angle), math.sin(angle)
  local q = 1
  if x < 0 then q = q + 1 end
  if y > 0 then q = q + 2 end
  local quad = MINIMAP_SHAPES[(GetMinimapShape and GetMinimapShape()) or "ROUND"] or MINIMAP_SHAPES.ROUND
  local w = (Minimap:GetWidth() / 2) + 8
  local h = (Minimap:GetHeight() / 2) + 8
  if quad[q] then
    x, y = x * w, y * h
  else
    x = math.max(-w, math.min(x * (math.sqrt(2 * w * w) - 10), w))
    y = math.max(-h, math.min(y * (math.sqrt(2 * h * h) - 10), h))
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- While dragging, follow the cursor's angle around the minimap centre.
local function DragUpdate()
  local mx, my = Minimap:GetCenter()
  local scale  = Minimap:GetEffectiveScale()
  local px, py = GetCursorPosition()
  px, py = px / scale, py / scale
  ns.db.minimap.angle = math.deg(math.atan2(py - my, px - mx)) % 360
  UpdatePosition()
end

-- Anchor the tooltip on whichever side keeps it on-screen: button on the right
-- half of the screen -> tooltip to its left, and vice versa.
local function TooltipAnchor(self)
  local cx = self:GetCenter()
  if cx and cx > UIParent:GetWidth() / 2 then return "ANCHOR_LEFT" end
  return "ANCHOR_RIGHT"
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
  -- Pin strata/level so another addon (or the minimap cluster) can't restack
  -- the button underneath the minimap.
  b:SetFrameStrata("MEDIUM")
  b:SetFixedFrameStrata(true)
  b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  b:SetFixedFrameLevel(true)
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
      ShowMenu()
    else
      ns:ToggleMainWindow()
    end
  end)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, TooltipAnchor(self))
    GameTooltip:AddLine("Action Bar Master")
    GameTooltip:AddLine("Left-click to open", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click for menu", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
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

-- Register an entry in Blizzard's addon compartment (the menu at the top of the
-- minimap) — a stable access point even when the minimap button is hidden.
-- Additive and library-free; retail-only, hence the guard.
local function RegisterCompartment()
  if not AddonCompartmentFrame then return end
  AddonCompartmentFrame:RegisterAddon({
    text         = "Action Bar Master",
    icon         = ICON,
    notCheckable = true,
    func         = function() ns:ToggleMainWindow() end,
    funcOnEnter  = function(frame)
      GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
      GameTooltip:AddLine("Action Bar Master")
      GameTooltip:AddLine("Click to open", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end,
    funcOnLeave  = function() GameTooltip:Hide() end,
  })
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
  RegisterCompartment()
end)
