local abm = require("spec.abm")

-- restore_slots.lua touches no WoW API at LOAD time (every C_* reference is
-- and-guarded), so ns.RestoreSlots can be driven out of game against the fake
-- action bar in spec/abm.lua. These specs cover the petaction/futurespell branch
-- (#131): both types are documented as "cleared on restore", but picking the
-- action up without dropping it let the shared place/blank tail put it straight
-- back, so a pre-existing action survived a restore that should have blanked it.
describe("ns.RestoreSlots", function()
  local ns, bars, misses, warns

  -- SLOT 5 -> abm bar 1 ("Bar 1"), column 5.
  local SLOT, LABEL = 5, "Bar 1 slot 5: "

  ---@param initial table? starting bar contents, { [slotID] = { type, index } }
  local function setup(initial)
    -- the bar stubs must exist BEFORE load: restore_slots.lua captures PickupSpell
    -- into a file-local upvalue at load time
    bars = abm.actionbars(initial)
    ns   = abm.load({ "restore_slots.lua" })
    misses, warns = {}, {}
    ns.RestoreMiss = function(msg) misses[#misses + 1] = msg end
    ns.Print       = function(msg) warns[#warns + 1] = msg end
  end

  local function restore(slots)
    ns.RestoreSlots(slots, {}, {}, "Orc", "WARRIOR")
  end

  for _, case in ipairs({
    { type = "petaction",   miss = "Pet action can't be restored" },
    { type = "futurespell", miss = "Unlearned spell can't be restored" },
  }) do
    describe(case.type .. " slots", function()
      it("blanks a slot the character already has an action in", function()
        setup({ [SLOT] = { "spell", 1234 } })
        restore({ { id = SLOT, type = case.type } })
        assert.is_nil(bars.slots[SLOT])
      end)

      it("leaves an already-empty slot empty", function()
        setup()
        restore({ { id = SLOT, type = case.type } })
        assert.is_nil(bars.slots[SLOT])
        assert.are.same({}, warns)   -- no "Slot error:" from the pcall
      end)

      it("blanks a slot that already holds the same type", function()
        -- the "current state already matches" early-out must not apply here: the
        -- wanted state for these types is empty, never "whatever is there now"
        setup({ [SLOT] = { case.type } })
        restore({ { id = SLOT, type = case.type } })
        assert.is_nil(bars.slots[SLOT])
      end)

      it("reports the cleared slot as a miss", function()
        setup({ [SLOT] = { "spell", 1234 } })
        restore({ { id = SLOT, type = case.type } })
        assert.are.same({ LABEL .. case.miss }, misses)
      end)

      it("drops the picked-up action instead of leaking it onto the cursor", function()
        -- the bug: a non-empty cursor at the tail placed the action back into the
        -- slot; a leak would also swap into whichever slot the loop handles next
        setup({ [SLOT] = { "spell", 1234 }, [SLOT + 1] = { "spell", 5678 } })
        restore({
          { id = SLOT,     type = case.type },
          { id = SLOT + 1, type = "spell", index = 99 },
        })
        assert.is_nil(bars.cursor)
        assert.is_nil(bars.slots[SLOT])
        assert.are.same({ "spell", 99 }, bars.slots[SLOT + 1])
      end)
    end)
  end

  it("still places an ordinary spell slot", function()
    setup()
    restore({ { id = SLOT, type = "spell", index = 42 } })
    assert.are.same({ "spell", 42 }, bars.slots[SLOT])
    assert.is_nil(bars.cursor)
    assert.are.same({}, misses)
  end)

  it("leaves a spell slot that already holds that spell untouched", function()
    setup({ [SLOT] = { "spell", 42 } })
    restore({ { id = SLOT, type = "spell", index = 42 } })
    assert.are.same({ "spell", 42 }, bars.slots[SLOT])
  end)
end)
