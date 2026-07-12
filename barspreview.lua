local _, ns = ...
local ui = ns.ui

local LBL_H = 14     -- title line
-- The preview FILLS the viewport: scaled to the largest size that fits both axes
-- (so it uses the whole panel, not a fixed zoom), capped at MAX_SCALE so a tiny
-- profile doesn't magnify absurdly. The window (window.lua) is sized generously
-- so a full setup fills at a comfortable size.
local MAX_SCALE = 1.75

local GetSpellName = C_Spell and C_Spell.GetSpellName or function(id) return (GetSpellInfo(id)) end

-- Pet-bar slot name: spell abilities by ID, command tokens by their captured name.
local function petName(slot)
  if slot.type == "spell" then return GetSpellName(slot.index) end
  return slot.strindex
end

---Build the primary bar view: a read-only **topographic layout preview** that
---renders the selected (or live) profile in its real on-screen orientation via
---LibNUI's `ui.BarsPreview`, using ABM's own slot icon/name resolvers. Which bars
---a Save/Load applies to is chosen in the companion strip (`ns.BuildBarSelect`);
---this view is the spatial reference, and its bars light up (`Highlight`) as the
---strip's chips are hovered. The topography (including right-docked vertical bars,
---which can push it wider than the panel) is **scaled to fit** the viewport at up
---to MAX_SCALE, so nothing is clipped off-screen. Fills `parent`.
---@param parent table  container frame
---@return { Update: fun(profile: table?), Highlight: fun(abm: integer, on: boolean) }
function ns.BuildBarsPreview(parent)
  local title = ui.Label:new{
    parent   = parent, fontObj = "GameFontHighlightSmall", color = "muted", wordWrap = false,
    justifyH = "CENTER",
    position = {
      TopLeft = { parent, ui.edge.TopLeft, 0, 0 },
      Right   = { parent, ui.edge.Right,   0, 0 },
      Height  = LBL_H,
    },
  }

  -- Fixed viewport below the title. The preview is scaled to fit inside it, so the
  -- clip is only a safety net for the frame or two before the first fit.
  local stage = ui.Frame:new{
    parent   = parent,
    position = {
      TopLeft     = { parent, ui.edge.TopLeft,     0, -(LBL_H + 4) },
      BottomRight = { parent, ui.edge.BottomRight, 0, 0 },
    },
  }
  stage._widget:SetClipsChildren(true)

  -- ABM-owned wrapper we scale (leaving the shared ui.BarsPreview untouched). It
  -- is sized to the preview's real extent and anchored top-centre in the stage, so
  -- scaling it keeps the map centered.
  local holder = ui.Frame:new{
    parent   = stage,
    position = { Top = { stage, ui.edge.Top, 0, 0 }, Width = 1, Height = 1 },
  }

  -- Current profile's macros (array). The widget passes its own macro MAP to the
  -- resolvers, but ABM's ns._bar_getIcon/_getName scan the array form the addon
  -- already builds, so the resolvers close over this and ignore the passed map.
  local macros = {}

  local preview = ui.BarsPreview:new{
    parent   = holder,
    position = { TopLeft = { holder, ui.edge.TopLeft, 0, 0 } },
    resolveIcon    = function(slot) return ns._bar_getIcon(slot, macros) end,
    resolveName    = function(slot) return ns._bar_getName(slot, macros) end,
    resolvePetIcon = function(slot) return ns._bar_getPetIcon(slot) end,
    resolvePetName = petName,
  }

  -- Scale the holder so the preview fills the stage — the largest scale that fits
  -- both axes, capped at MAX_SCALE. Re-run on profile/size change.
  local function fit()
    local pw, ph = preview:Width(), preview:Height()
    if not pw or not ph or pw < 1 or ph < 1 then return end
    holder:Width(pw); holder:Height(ph)
    local sw, sh = stage:Width(), stage:Height()
    if not sw or not sh or sw < 1 or sh < 1 then return end   -- panel not laid out yet
    holder._widget:SetScale(math.min(sw / pw, sh / ph, MAX_SCALE))
  end

  local function Update(profile)
    if not profile then
      title:Text("")
      preview:Set(nil)
      return
    end
    macros = profile.macros or {}
    title:Text((profile.char or "?") .. "  \226\128\148  " .. (profile.spec ~= "" and profile.spec or "shared"))
    preview:Set(profile)
    fit()
  end

  -- The first Open updates before the window is shown, so the stage has no size
  -- yet at that Update; re-fit once it gets laid out.
  stage._widget:SetScript("OnSizeChanged", fit)

  ---Light up (or clear) the preview row for an abm bar — driven by the select
  ---strip's chip hover. No-op for bars the preview isn't currently showing.
  local function Highlight(abm, on) preview:HighlightBar(abm, on) end

  return { Update = Update, Highlight = Highlight }
end
