local _, ns = ...
local ui = ns.ui

local P, LBL_H, GAP = 8, 14, 6

local GetSpellName = C_Spell and C_Spell.GetSpellName or function(id) return (GetSpellInfo(id)) end

-- Pet-bar slot name: spell abilities by ID, command tokens by their captured name.
local function petName(slot)
  if slot.type == "spell" then return GetSpellName(slot.index) end
  return slot.strindex
end

---Build a read-only "live layout" preview docked to the right of the main window.
---Renders the selected (or live) profile in its real on-screen orientation via
---LibNUI's `ui.BarsPreview`, using ABM's own slot icon/name resolvers. The
---interactive grid is untouched — this is a separate spatial reference.
---@param parent table  the main window frame
---@return { Update: fun(profile: table?) }
function ns.BuildBarsPreview(parent)
  -- Docked to the window's right edge; parented to it so it follows drags and
  -- hides with it. clamped=false — it deliberately extends past the clamped window.
  local box = ui.CleanFrame:new{
    parent   = parent,
    clamped  = false,
    position = { TopLeft = { parent, ui.edge.TopRight, GAP, 0 }, Width = 1, Height = 1, Hide = true },
  }

  box.title = ui.Label:new{
    parent   = box, fontObj = "GameFontHighlightSmall", color = "muted", wordWrap = false,
    position = { TopLeft = { box, ui.edge.TopLeft, P, -P }, Height = LBL_H },
  }

  -- Current profile's macros (array). The widget passes its own macro MAP to the
  -- resolvers, but ABM's ns._bar_getIcon/_getName scan the array form the addon
  -- already builds, so the resolvers close over this and ignore the passed map.
  local macros = {}

  local preview = ui.BarsPreview:new{
    parent   = box,
    position = { TopLeft = { box, ui.edge.TopLeft, 0, -(P + LBL_H) } },
    resolveIcon    = function(slot) return ns._bar_getIcon(slot, macros) end,
    resolveName    = function(slot) return ns._bar_getName(slot, macros) end,
    resolvePetIcon = function(slot) return ns._bar_getPetIcon(slot) end,
    resolvePetName = petName,
  }

  local function Update(profile)
    if not profile then box:Hide(); return end
    macros = profile.macros or {}
    box.title:Text((profile.char or "?") .. "  \226\128\148  " .. (profile.spec ~= "" and profile.spec or "shared"))
    preview:Set(profile)
    local w = math.max(preview:Width(), 120)
    box:Width(w)
    box.title:Width(w - 2 * P)
    box:Height(P + LBL_H + preview:Height())
    box:Show()
  end

  return { Update = Update }
end
