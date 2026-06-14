local abm = require("spec.abm")

describe("ns serialize (Encode/Decode)", function()
  local ns

  before_each(function()
    ns = abm.load()
  end)

  local function roundtrip(profile)
    local encoded = ns.Encode(profile)
    local decoded, err = ns.Decode(encoded)
    assert.is_nil(err)
    assert.is_table(decoded)
    return decoded
  end

  it("round-trips a full profile (v2)", function()
    local profile = {
      char = "Tester", class = "MAGE", spec = "Fire",
      slots = {
        { id = 1, type = "spell",      index = 133 },
        { id = 2, type = "item",       index = 6948 },
        { id = 3, type = "macro",      index = 5 },
        { id = 4, type = "summonpet",  strindex = "BattlePet-0-000000AABBCC" },
        { id = 5, type = "profession", index = 1, profSlot = 2, strindex = "Mining" },
        { id = 6, type = "equipmentset", index = 2, strindex = "Raid" },
      },
      binds = {
        { command = "JUMP",        key1 = "SPACE" },
        { command = "MOVEFORWARD", key1 = "W", key2 = "UP" },
      },
      macros   = { { id = 5, name = "Cast", icon = "INV_MISC_QUESTIONMARK", body = "/cast Fireball" } },
      petslots = { { id = 1, type = "spell", index = 2645 } },
    }
    local d = roundtrip(profile)
    assert.equal("Tester", d.char)
    assert.equal("MAGE", d.class)
    assert.equal("Fire", d.spec)
    assert.same(profile.slots, d.slots)
    assert.same(profile.binds, d.binds)
    assert.same(profile.macros, d.macros)
    assert.same(profile.petslots, d.petslots)
  end)

  it("round-trips a partial/shared profile (v3 captured-bars list)", function()
    local profile = {
      char = "Tester", class = "", spec = "",
      slots = { { id = 13, type = "spell", index = 100 } },
      binds = {}, macros = {}, petslots = {},
      bars  = { 2, 4, 7 },
    }
    local d = roundtrip(profile)
    assert.same({ 2, 4, 7 }, d.bars)
    assert.same(profile.slots, d.slots)
  end)

  it("preserves a large spell ID near the int24 ceiling", function()
    local profile = {
      char = "X", class = "", spec = "",
      slots = { { id = 1, type = "spell", index = 1200000 } },
      binds = {}, macros = {}, petslots = {},
    }
    assert.equal(1200000, roundtrip(profile).slots[1].index)
  end)

  it("returns an error for too-short input", function()
    local d, err = ns.Decode("# Action Bar Master\nZZZZ\n")
    assert.is_nil(d)
    assert.is_string(err)
  end)

  it("detects tampering via CRC mismatch", function()
    local encoded = ns.Encode({
      char = "Tester", class = "MAGE", spec = "Fire",
      slots = { { id = 1, type = "spell", index = 133 } },
      binds = {}, macros = {}, petslots = {},
    })
    -- corrupt the first base64 body line (comment lines are stripped before
    -- the CRC check, so tampering one of those would be a no-op)
    local lines = {}
    for line in (encoded .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    for i, line in ipairs(lines) do
      if line ~= "" and line:sub(1, 1) ~= "#" then
        local first = line:sub(1, 1)
        lines[i] = (first == "A" and "B" or "A") .. line:sub(2)
        break
      end
    end
    local d, err = ns.Decode(table.concat(lines, "\n"))
    assert.is_nil(d)
    assert.is_string(err)
  end)
end)
