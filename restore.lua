local _, ns = ...

local PickupItem    = C_Item  and C_Item.PickupItem      or _G.PickupItem

local MAX_BARS = 180

local function Warn(msg)
  ns.Print("|cffff9900[Bars]|r " .. msg)
end

-- A "miss" is a slot whose content simply isn't available on this character
-- (an unowned item, a missing equipment set/outfit, an unlearned profession,
-- etc.) — expected on cross-character restores. Rather than print one chat
-- line per miss (which floods the log), they are collected and flushed as a
-- single summary at the end of the restore. True errors still use Warn.
local misses = {}
local restoreFinished = false
local pendingItems = 0  -- async item-info lookups still outstanding

local function Miss(msg)
  misses[#misses + 1] = msg
end

local function FlushMisses()
  if #misses == 0 then return end
  Warn(#misses .. (#misses == 1 and " slot was" or " slots were")
    .. " left blank — content not available on this character:")
  ns.Print("|cffff9900[Bars]|r " .. table.concat(misses, ",  "))
  wipe(misses)
end

local pendingItemWarns = {}

ns:registerEvent("GET_ITEM_INFO_RECEIVED", function(self, itemID, success)
  local pend = pendingItemWarns[itemID]
  if not pend then return end
  pendingItemWarns[itemID] = nil
  pendingItems = pendingItems - 1

  -- Retry placement now that the item's data has loaded: PickupItem(link)
  -- resolves items that only respond to the link form, which the ID-only pickup
  -- at restore time missed. Guard combat (this event can fire well after the
  -- restore window) and only fill if the slot is still empty, so we don't
  -- clobber a change the user made in the meantime.
  local placed = false
  if success and not InCombatLockdown() and not GetActionInfo(pend.id) then
    ClearCursor()
    local link = select(2, GetItemInfo(itemID))
    if link then PickupItem(link) end
    if not GetCursorInfo() then PickupItem(itemID) end
    if GetCursorInfo() then PlaceAction(pend.id) end
    ClearCursor()
    placed = GetActionInfo(pend.id) ~= nil
  end

  if not placed then
    local link = (success and select(2, GetItemInfo(itemID)))
               or ("|Hitem:" .. itemID .. "|h[item:" .. itemID .. "]|h")
    Miss(pend.label .. "Missing item " .. link)
  end
  if restoreFinished and pendingItems == 0 then FlushMisses() end
end)

-- Expose the miss / deferred-item hooks to restore_slots.lua's ns.RestoreSlots. The
-- state above (misses / pendingItems / pendingItemWarns / restoreFinished) stays
-- file-local here; ns.Restore below resets it on entry and flushes on completion.
ns.RestoreMiss = Miss
function ns.DeferItemWarn(itemID, slotID, label)
  -- defer: warn (and retry placement) once the item's data loads
  pendingItemWarns[itemID] = { id = slotID, label = label }
  pendingItems = pendingItems + 1
  C_Item.RequestLoadItemDataByID(itemID)
end

---Apply a profile to the current character.
---@param profile table
---@param barFilter table? optional map of bar numbers (and "pet") to bool; nil/true = restore, false = skip
function ns.Restore(profile, barFilter)
  if InCombatLockdown() then
    ns.Print("Cannot restore during combat.")
    return
  end
  wipe(misses)
  -- Also drop any still-pending item-info deferrals from a PRIOR restore. Their delayed
  -- GET_ITEM_INFO_RECEIVED would otherwise decrement this restore's freshly-reset
  -- pendingItems (no floor → -1), corrupting the end-of-restore flush guard: this restore
  -- supersedes the last, so its stale retries/misses are moot. The event handler ignores
  -- an itemID with no live entry, so in-flight events for the old restore no-op.
  wipe(pendingItemWarns)
  restoreFinished = false
  pendingItems    = 0

  local overrides, flyouts = ns.BuildSpellbookMaps()
  local _, race   = UnitRace("player")
  local _, class  = UnitClass("player")

  local slots    = profile.slots    or {}
  local petslots = profile.petslots or {}

  -- Partial profiles only touch their captured bars: restrict slot restore AND
  -- unused-slot clearing to the intersection of the captured set and the
  -- caller's barFilter. Bars outside the captured set are left untouched.
  if profile.bars then
    local captured = {}
    for _, b in ipairs(profile.bars) do captured[b] = true end
    local merged = {}
    for b = 1, MAX_BARS / 12 do
      merged[b] = (captured[b] and (not barFilter or barFilter[b] ~= false)) or false
    end
    merged.pet = ((#petslots > 0) and (not barFilter or barFilter.pet ~= false)) or false
    barFilter = merged
  end

  if barFilter then
    local filtered = {}
    for _, s in ipairs(slots) do
      local bar = math.floor((s.id - 1) / 12) + 1
      if barFilter[bar] ~= false then
        filtered[#filtered + 1] = s
      end
    end
    slots = filtered
    if barFilter.pet == false then petslots = {} end
  end

  ns.RestoreFlyouts(slots, flyouts)
  ns.RestoreMacrosAndSlots(profile.macros or {}, slots)
  ns.RestoreSlots(slots, overrides, flyouts, race, class)
  ns.ClearUnusedSlots(slots, barFilter)
  if #(profile.binds or {}) > 0 then
    ns.RestoreBindings(profile.binds)
  end
  ns.RestorePetBar(petslots)
  ns.Print("Bars restored.")

  -- flush the collected misses as one summary; if item-info lookups are still
  -- pending, the GET_ITEM_INFO_RECEIVED handler flushes once the last resolves
  restoreFinished = true
  if pendingItems == 0 then FlushMisses() end
end
