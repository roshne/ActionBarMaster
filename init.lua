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
end
