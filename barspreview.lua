local _, ns = ...
local ui = ns.ui

local LBL_H = 14

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
---strip's chips are hovered. Fills `parent`: a title line above a scroll area.
---@param parent table  container frame
---@return { Update: fun(profile: table?), Highlight: fun(abm: integer, on: boolean) }
function ns.BuildBarsPreview(parent)
  local title = ui.Label:new{
    parent   = parent, fontObj = "GameFontHighlightSmall", color = "muted", wordWrap = false,
    position = { TopLeft = { parent, ui.edge.TopLeft, 0, 0 }, Height = LBL_H },
  }

  -- The condensed topography can be taller than the panel; a scroll frame absorbs
  -- the overflow (auto-hiding scrollbar when it fits). content sizes to the
  -- preview's real extent on every Update.
  local scroll = ui.ScrollFrame:new{
    parent    = parent,
    scrollbar = true,
    position  = {
      TopLeft     = { parent, ui.edge.TopLeft,     0, -(LBL_H + 4) },
      BottomRight = { parent, ui.edge.BottomRight, 0, 0 },
    },
  }
  local content = ui.Frame:new{
    parent   = scroll,
    position = { TopLeft = { scroll, ui.edge.TopLeft, 0, 0 }, Width = 1, Height = 1 },
  }
  scroll:Child(content)

  -- Current profile's macros (array). The widget passes its own macro MAP to the
  -- resolvers, but ABM's ns._bar_getIcon/_getName scan the array form the addon
  -- already builds, so the resolvers close over this and ignore the passed map.
  local macros = {}

  local preview = ui.BarsPreview:new{
    parent   = content,
    position = { TopLeft = { content, ui.edge.TopLeft, 0, 0 } },
    resolveIcon    = function(slot) return ns._bar_getIcon(slot, macros) end,
    resolveName    = function(slot) return ns._bar_getName(slot, macros) end,
    resolvePetIcon = function(slot) return ns._bar_getPetIcon(slot) end,
    resolvePetName = petName,
  }

  local function Update(profile)
    if not profile then
      title:Text("")
      preview:Set(nil)
      content:Width(1); content:Height(1)
      scroll:Refresh()
      return
    end
    macros = profile.macros or {}
    title:Text((profile.char or "?") .. "  \226\128\148  " .. (profile.spec ~= "" and profile.spec or "shared"))
    preview:Set(profile)
    content:Width(preview:Width())
    content:Height(preview:Height())
    scroll:Refresh()
  end

  ---Light up (or clear) the preview row for an abm bar — driven by the select
  ---strip's chip hover. No-op for bars the preview isn't currently showing.
  local function Highlight(abm, on) preview:HighlightBar(abm, on) end

  return { Update = Update, Highlight = Highlight }
end
