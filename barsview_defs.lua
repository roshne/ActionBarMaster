local _, ns = ...

-- Static bar definitions: ABM slot mapping + WoW display label, in default
-- display order. abmToBarDef is the lookup used when reconstructing ordered
-- rows from db.barOrder. The hardcoded seed in init.lua's MigrateDB mirrors
-- DEFAULT_ORDER deliberately — migration output must stay frozen even if the
-- display default changes later.
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

local DEFAULT_ORDER = {}
for _, def in ipairs(BAR_DEFS) do DEFAULT_ORDER[#DEFAULT_ORDER + 1] = def.abm end

---Returns the ordered array of bar defs ({ abm, label }) to display,
---sourced from db.barOrder (falling back to the default order).
---@return table[]
function ns.GetActiveBarOrder()
  local source = (ns.db and ns.db.barOrder) or DEFAULT_ORDER
  local result = {}
  for _, abm in ipairs(source) do
    local def = abmToBarDef[abm]
    if def then result[#result + 1] = def end
  end
  return result
end
