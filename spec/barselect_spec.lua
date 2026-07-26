local abm = require("spec.abm")

-- barselect.lua builds LibNUI frames, but everything that MATTERS about it is
-- bookkeeping: which bars are included, whether they all are, and who gets told
-- when that changes. abm.nui() doubles just enough of the widget surface to build
-- the strip headlessly, so that bookkeeping is guarded out of game (#132).
--
-- Chip order is barselect.lua's CHIPS list; abm.nui() records every Button in
-- creation order, so buttons[i] is the chip for CHIP_KEYS[i].
local CHIP_KEYS = { 1, 6, 5, 3, 4, 13, 14, 15, 7, 8, 9, 10, 12, 2, 11, "pet" }

local CHIP_INDEX = {}
for i, key in ipairs(CHIP_KEYS) do CHIP_INDEX[key] = i end

describe("ns.BuildBarSelect", function()
  local nui, select_

  before_each(function()
    nui = abm.nui()
    local ns = abm.load({ "barselect.lua" }, nui)
    select_ = ns.BuildBarSelect({})
  end)

  ---Click the chip for a bar key the way the widget's OnClick script does.
  local function clickChip(key)
    local i = assert(CHIP_INDEX[key], "no chip for key " .. tostring(key))
    nui.buttons[i].OnClick()
  end

  it("builds one chip per bar plus Pet, all included", function()
    assert.are.equal(#CHIP_KEYS, #nui.buttons)
    local checked = select_.GetChecked()
    for _, key in ipairs(CHIP_KEYS) do
      assert.is_true(checked[key], "chip " .. tostring(key) .. " should default to included")
    end
    assert.is_true(select_.AllChecked())
  end)

  it("excludes only the clicked chip's bar", function()
    clickChip(5)
    local checked = select_.GetChecked()
    assert.is_false(checked[5])
    for _, key in ipairs(CHIP_KEYS) do
      if key ~= 5 then assert.is_true(checked[key]) end
    end
  end)

  it("toggles a chip back on with a second click", function()
    clickChip("pet")
    assert.is_false(select_.GetChecked().pet)
    clickChip("pet")
    assert.is_true(select_.GetChecked().pet)
  end)

  -- The filter is held across the Load confirmation popup (window.lua), during
  -- which the chips behind it stay clickable. Handing out the live table let a
  -- click widen a restore the user had already committed to.
  it("returns a snapshot, not the live chip table", function()
    local taken = select_.GetChecked()
    clickChip(5)
    assert.is_true(taken[5], "an already-issued filter must not see later chip clicks")
    assert.is_false(select_.GetChecked()[5], "a fresh read must see them")
  end)

  it("does not let a caller mutate the chip state through the snapshot", function()
    local taken = select_.GetChecked()
    taken[5] = false
    assert.is_true(select_.GetChecked()[5])
    assert.is_true(select_.AllChecked())
  end)

  it("SetAllChecked drives every chip in both directions", function()
    select_.SetAllChecked(false)
    local off = select_.GetChecked()
    for _, key in ipairs(CHIP_KEYS) do
      assert.is_false(off[key], "chip " .. tostring(key) .. " should be excluded")
    end
    assert.is_false(select_.AllChecked())

    select_.SetAllChecked(true)
    local on = select_.GetChecked()
    for _, key in ipairs(CHIP_KEYS) do assert.is_true(on[key]) end
    assert.is_true(select_.AllChecked())
  end)

  it("AllChecked tracks chips ticked one at a time", function()
    clickChip(1)
    assert.is_false(select_.AllChecked())
    clickChip(2)
    assert.is_false(select_.AllChecked())
    clickChip(1)
    clickChip(2)
    assert.is_true(select_.AllChecked())
  end)

  -- The window's Check All / Uncheck All label is derived from this ping. Before
  -- #132 it tracked a private flag, so unticking every chip by hand left the label
  -- reading "Uncheck All" and the first click on it was a no-op.
  describe("SetOnChanged", function()
    local calls

    before_each(function()
      calls = {}
      select_.SetOnChanged(function(all) calls[#calls + 1] = all end)
    end)

    it("reports the aggregate after a chip click", function()
      clickChip(5)
      assert.are.same({ false }, calls)
      clickChip(5)
      assert.are.same({ false, true }, calls)
    end)

    it("reports the aggregate after SetAllChecked", function()
      select_.SetAllChecked(false)
      select_.SetAllChecked(true)
      assert.are.same({ false, true }, calls)
    end)

    it("reports not-all-checked once the last chip is unticked by hand", function()
      for _, key in ipairs(CHIP_KEYS) do clickChip(key) end
      assert.are.equal(#CHIP_KEYS, #calls)
      for _, all in ipairs(calls) do assert.is_false(all) end
      assert.is_false(select_.AllChecked())
    end)
  end)
end)
