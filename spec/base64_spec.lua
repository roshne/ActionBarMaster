local abm = require("spec.abm")

describe("ns.base64", function()
  local base64

  before_each(function()
    base64 = abm.load().base64
  end)

  it("round-trips arbitrary byte arrays", function()
    local cases = {
      {},
      {0},
      {255},
      {72, 105},                       -- "Hi"
      {0, 1, 2, 3, 4, 5, 253, 254, 255},
    }
    for _, bytes in ipairs(cases) do
      assert.same(bytes, base64.dec(base64.enc(bytes)))
    end
  end)

  it("encodes the canonical RFC 4648 vectors", function()
    assert.equal("TWFu", base64.enc({77, 97, 110}))   -- "Man"
    assert.equal("TWE=", base64.enc({77, 97}))         -- "Ma"
    assert.equal("TQ==", base64.enc({77}))             -- "M"
  end)

  it("ignores non-alphabet characters when decoding", function()
    assert.same({77, 97, 110}, base64.dec("TW\nFu  "))
  end)
end)
