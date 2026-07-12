local _, ns = ...

-- Static bar definitions: ABM slot mapping + WoW display label. `GetBarLabel`
-- (via abmToBarDef) names an abm bar number the way the UI and on-screen overlay
-- do — used by restore warnings, the bar overlay, and the duplicate scanner.
-- Bar display order is now driven by real on-screen topography (the preview), so
-- there is no user-configurable row order any more (the legacy db.barOrder key is
-- retained for rollback safety but unread — see init.lua).
local BAR_DEFS = {
  { abm = 1,  label = "Bar 1"     },
  { abm = 6,  label = "Bar 2"     },
  { abm = 5,  label = "Bar 3"     },
  { abm = 3,  label = "Bar 4"     },
  { abm = 4,  label = "Bar 5"     },
  { abm = 13, label = "Bar 6"     },
  { abm = 14, label = "Bar 7"     },
  { abm = 15, label = "Bar 8"     },
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

---Returns the UI display label for an abm bar number (e.g. 5 -> "Bar 3").
---Used by restore warnings and the bar overlay so they name the same rows the UI shows.
---@param abm integer
---@return string
function ns.GetBarLabel(abm)
  local def = abmToBarDef[abm]
  return def and def.label or ("Bar " .. abm)
end
