local _, ns = ...
local ui = ns.ui

local ICON          = "Interface\\AddOns\\ActionBarMaster\\textures\\minimap.png"
local DEFAULT_ANGLE = 198  -- degrees around the ring (lower-left, clear of default UI)

local button  -- ui.MinimapButton, created at login

---Show or hide the minimap button and persist the choice.
---@param show boolean
function ns.SetMinimapShown(show)
  if button then button:Shown(show) end
end

ns:registerCommand("minimap", nil, function()
  local show = not button:Shown()  -- toggle from current state
  button:Shown(show)
  ns.Print(show and "Minimap button shown." or "Minimap button hidden.")
end, "Toggle the minimap button")

ns:registerEvent("PLAYER_LOGIN", function()
  ns.db.minimap = ns.db.minimap or {}  -- lazy-init store (no DB version bump)
  button = ui.MinimapButton:new{
    name            = "ActionBarMasterMinimapButton",
    icon            = ICON,
    iconFillsButton = true,  -- the medallion art carries its own stone border
    db              = ns.db.minimap,
    defaultAngle    = DEFAULT_ANGLE,
    tooltip         = {
      "Action Bar Master",
      "Left-click to open",
      "Right-click for menu",
      "Drag to move",
    },
    onClick = function(self, mouseButton)
      if mouseButton == "RightButton" then
        self:ShowContextMenu(function(_, root)
          root:CreateTitle("Action Bar Master")
          root:CreateButton("Open", function() ns:Open() end)
          root:CreateButton("Hide minimap button", function() self:Shown(false) end)
        end)
      else
        ns:ToggleMainWindow()
      end
    end,
    compartment = { text = "Action Bar Master", onClick = function() ns:ToggleMainWindow() end },
  }
end)
