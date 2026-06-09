local _, ns = ...

LibNAddOn{
  name    = "ActionBarMaster",
  addOn   = ns,
}

function ns:MigrateDB()
  local db = self.db
  if not db.version then
    db.profiles = {}
    db.version  = 1
  end
  if db.version < 2 then
    -- Seed bar display order from the hardcoded default (abm bar numbers in display order)
    db.barOrder = { 1, 6, 5, 3, 4, 13, 14, 15, 2, 7, 8, 9, 10, 12, 11 }
    db.version  = 2
  end
end
