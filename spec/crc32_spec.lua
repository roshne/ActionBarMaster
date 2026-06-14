local abm = require("spec.abm")

local function bytes(s)
  local t = {}
  for i = 1, #s do t[i] = s:byte(i) end
  return t
end

describe("ns.crc32", function()
  local crc32

  before_each(function()
    crc32 = abm.load().crc32
  end)

  it("matches the standard CRC-32 check value", function()
    -- CRC-32/ISO-HDLC of "123456789" is 0xCBF43926
    assert.equal(0xCBF43926, crc32.enc(bytes("123456789")) % 0x100000000)
  end)

  it("is deterministic and input-sensitive", function()
    assert.equal(crc32.enc(bytes("hello")), crc32.enc(bytes("hello")))
    assert.are_not.equal(crc32.enc(bytes("hello")), crc32.enc(bytes("world")))
  end)
end)
