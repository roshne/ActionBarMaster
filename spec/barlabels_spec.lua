local abm = require("spec.abm")

-- barlabels.lua is WoW-API-free (a static abm-bar-number -> display-label table),
-- so it can be exercised out of game. This guards ns.GetBarLabel, which the
-- restore warnings, the on-screen bar overlay, and the duplicate scanner all use
-- to name a bar the way the UI does. The bar-select strip (barselect.lua) reuses
-- the same abm bar numbers, so a drift here would mislabel bars everywhere.
describe("ns.GetBarLabel", function()
  local ns

  before_each(function()
    ns = abm.load()
  end)

  it("maps every abm bar number to its UI display label", function()
    local expected = {
      [1] = "Bar 1", [6] = "Bar 2", [5]  = "Bar 3", [3]  = "Bar 4", [4]  = "Bar 5",
      [13] = "Bar 6", [14] = "Bar 7", [15] = "Bar 8",
      [2] = "Bonus",
      [7] = "Class 1", [8] = "Class 2", [9] = "Class 3", [10] = "Class 4", [12] = "Class 5",
      [11] = "Skyriding",
    }
    for abmBar, label in pairs(expected) do
      assert.are.equal(label, ns.GetBarLabel(abmBar))
    end
  end)

  it("covers all 15 bars with a distinct label", function()
    local seen = {}
    for abmBar = 1, 15 do
      local label = ns.GetBarLabel(abmBar)
      assert.is_string(label)
      assert.is_nil(seen[label], "duplicate label: " .. tostring(label))
      seen[label] = true
    end
  end)

  it("falls back to 'Bar N' for an unknown bar number", function()
    assert.are.equal("Bar 99", ns.GetBarLabel(99))
  end)
end)
