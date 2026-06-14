local _, ns = ...
local ui = ns.ui

local WIN_W    = 828
local WIN_H    = 624
local LIST_W   = 240
local FILTER_W = 130
local PAD      = 8
local ROW_H    = 22
local BTN_H    = 22

local window = nil

local function savePosition(f)
  local x = f._widget:GetLeft() - UIParent:GetLeft()
  local y = f._widget:GetTop()  - UIParent:GetTop()
  f._widget:ClearAllPoints()
  f:TopLeft(UIParent, ui.edge.TopLeft, x, y)
  ns.db.windowPos = { x = x, y = y }
end

local function restorePosition(f)
  local pos = ns.db.windowPos
  if pos then
    f._widget:ClearAllPoints()
    f:TopLeft(UIParent, ui.edge.TopLeft, pos.x, pos.y)
  else
    savePosition(f)  -- freeze computed center into TOPLEFT anchor on first run
  end
end

local function CreateWindow()
  local f = ui.TitleFrame:new{
    name     = "ActionBarMasterWindow",
    title    = "Action Bar Master",
    special  = true,
    level    = 600,
    position = { Center = {-75, 150}, Width = WIN_W, Height = WIN_H },
  }

  f.titlebar:SetScript("OnMouseUp", function()
    f._widget:StopMovingOrSizing()
    savePosition(f)
  end)
  restorePosition(f)

  -- ── Column headers ───────────────────────────────────────────────────────
  local profilesHeader = ui.Label:new{
    parent   = f,
    text     = "Profiles",
    position = {
      TopLeft = { f.titlebar, ui.edge.BottomLeft, PAD, -PAD },
      Width   = LIST_W,
      Height  = ROW_H,
    },
  }

  -- ── Left panel (profile list) ────────────────────────────────────────────
  local listPanel = ui.CleanFrame:new{
    parent   = f,
    position = {
      TopLeft = { profilesHeader, ui.edge.BottomLeft, 0, -2 },
      Width   = LIST_W,
      Bottom  = { f, ui.edge.Bottom, 0, PAD + BTN_H + PAD + ROW_H + PAD },
    },
  }

  local function OnSelect(p)
    if not p then f._barsGrid.Update(nil); return end
    local profile, err = ns.Decode(p.encoded or "")
    if err then ns.Print("Decode error: " .. err) end
    f._barsGrid.Update(profile)
  end

  local _, refreshList, getSelected, setSelected, setClassFilter = ns.BuildProfileList(listPanel, OnSelect)
  f._refreshList = refreshList
  f._getSelected = getSelected

  -- Check All / Uncheck All: plain alternating toggle for the grid row
  -- checkboxes; the label always names the next click's action
  local CHECKALL_W = 90
  local allOn = true  -- checkboxes default to checked
  local checkAllBtn
  checkAllBtn = ui.Button:new{
    parent   = f,
    template = "UIPanelButtonTemplate",
    glow     = false,
    onClick  = function()
      allOn = not allOn
      f._barsGrid.SetAllChecked(allOn)
      checkAllBtn:Text(allOn and "Uncheck All" or "Check All")
    end,
    position = {
      TopLeft = { f.titlebar, ui.edge.BottomLeft, PAD + LIST_W + PAD, -PAD },
      Width   = CHECKALL_W,
      Height  = ROW_H,
    },
  }
  checkAllBtn:Text("Uncheck All")
  checkAllBtn:TextAlign("CENTER")

  ns.BuildClassFilter(f, {
    TopLeft = { f.titlebar, ui.edge.BottomLeft, PAD + LIST_W + PAD + CHECKALL_W + PAD, -PAD },
    Width   = FILTER_W,
    Height  = ROW_H,
  }, function(key, specOnly) setClassFilter(key, specOnly) end)

  -- ── Right panel (bars icon grid) ─────────────────────────────────────────
  local barsPanel = ui.Frame:new{
    parent   = f,
    position = {
      TopLeft     = { profilesHeader, ui.edge.BottomLeft, LIST_W + PAD, -2 },
      BottomRight = { f, ui.edge.BottomRight, -PAD, PAD + BTN_H + PAD + ROW_H + PAD },
    },
  }
  f._barsGrid = ns.BuildBarsGrid(barsPanel)

  -- ── Dialogs ──────────────────────────────────────────────────────────────
  local saveDialog = ns.BuildSaveDialog(f, function() refreshList() end)
  local expDlg     = ns.BuildExportDialog(f)
  local impDlg     = ns.BuildImportDialog(f, function(profile)
    f._pendingProfile   = profile
    f._pendingBarFilter = nil
    local what = profile.spec ~= "" and profile.spec or "shared bars"
    StaticPopup_Show("ABM_CONFIRM_IMPORT", profile.char .. " / " .. what)
  end)

  -- ── Bottom buttons ───────────────────────────────────────────────────────
  local W1, W2, BSEP, GSEP = 110, 60, 4, 20  -- wide btn, std btn, btn gap, group gap
  local lx1 = PAD
  local lx2 = lx1 + W1 + BSEP
  local lx3 = lx2 + W2 + BSEP
  local lx4 = lx3 + W2 + BSEP
  local rx1 = lx4 + W2 + GSEP
  local rx2 = rx1 + W2 + BSEP
  local rx3 = rx2 + W2 + BSEP
  local LX = { lx1, lx2, lx3, lx4 }
  local RX = { rx1, rx2, rx3 }

  local btnDefs = {
    {
      label = "Autosave Now", x = LX[1], w = 110,
      fn = function() ns.AutoSave(); refreshList() end,
    },
    {
      label = "Save", x = LX[2],
      fn = function()
        local checked = f._barsGrid.GetChecked()
        local total, inc = 0, 0
        for _, def in ipairs(ns.GetActiveBarOrder()) do
          total = total + 1
          if checked[def.abm] ~= false then inc = inc + 1 end
        end
        saveDialog._note:Text(inc == total
          and "Saving all bars (full profile)"
          or ("Saving " .. inc .. " of " .. total .. " bars |cff888888(shared, all classes)|r"))
        saveDialog:Show()
        saveDialog._nameBox:Text("")
        saveDialog._nameBox._widget:SetFocus()
      end,
    },
    {
      label = "Load", x = LX[3],
      fn = function()
        local p = getSelected()
        if not p then ns.Print("Select a profile first."); return end
        local profile, err = ns.Decode(p.encoded or "")
        if not profile then ns.Print("Load failed: " .. (err or "?")); return end
        f._pendingProfile   = profile
        f._pendingBarFilter = f._barsGrid.GetChecked()
        StaticPopup_Show("ABM_CONFIRM_IMPORT", p.name)
      end,
    },
    {
      label = "Delete", x = LX[4],
      fn = function()
        local p = getSelected()
        if not p then ns.Print("Select a profile first."); return end
        f._pendingDelete = p  -- hold the entry, not its index (issue #65)
        StaticPopup_Show("ABM_CONFIRM_DELETE", p.name)
      end,
    },
    {
      label = "Export", x = RX[1],
      fn = function()
        -- export the selected saved profile's own string (the only way to
        -- share another character's profile); fall back to a live capture of
        -- the current bars when nothing is selected
        local p = getSelected()
        local encoded = (p and p.encoded) or ns.Encode(ns.Capture())
        expDlg._box:Text(encoded)
        expDlg._box._widget:HighlightText(0, -1)
        expDlg:Show()
      end,
    },
    {
      label = "Import", x = RX[2],
      fn = function()
        impDlg._box:Text("")
        impDlg:Show()
        impDlg._box._widget:SetFocus()
      end,
    },
    {
      label = "Dupes", x = RX[3],
      fn = function() ns.OpenDupes() end,
    },
  }

  for _, def in ipairs(btnDefs) do
    local btn = ui.Button:new{
      parent   = f,
      template = "UIPanelButtonTemplate",
      glow     = false,
      onClick  = def.fn,
      position = {
        Left   = { f, ui.edge.Left,   def.x, 0  },
        Bottom = { f, ui.edge.Bottom, 0,     PAD },
        Width  = def.w or 60,
        Height = BTN_H,
      },
    }
    btn:Text(def.label)
    btn:TextAlign("CENTER")
  end

  StaticPopupDialogs["ABM_CONFIRM_DELETE"] = {
    text = "Delete '%s'?", button1 = DELETE, button2 = CANCEL,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function(self)
      -- resolve the entry's CURRENT index at accept time: an autosave inserting
      -- at index 1 during the confirm would otherwise shift a cached index onto
      -- the wrong profile. If it's gone (e.g. replaced in place by autosave),
      -- delete nothing rather than guess.
      local target = f._pendingDelete
      if target then
        for idx, p in ipairs(ns.db.profiles) do
          if p == target then
            table.remove(ns.db.profiles, idx)
            break
          end
        end
        setSelected(nil)
        refreshList()
        f._barsGrid.Update(nil)
      end
      f._pendingDelete = nil
    end,
    OnCancel = function(self) f._pendingDelete = nil end,
  }

  StaticPopupDialogs["ABM_CONFIRM_IMPORT"] = {
    text = "Restore bars from '%s'?", button1 = ACCEPT, button2 = CANCEL,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function(self)
      if f._pendingProfile then
        ns.Restore(f._pendingProfile, f._pendingBarFilter)
        f._pendingProfile   = nil
        f._pendingBarFilter = nil
      end
    end,
    OnCancel = function(self)
      f._pendingProfile   = nil
      f._pendingBarFilter = nil
    end,
  }

  return f
end

function ns:Open()
  if not window then window = CreateWindow() end
  window._refreshList()
  -- nothing selected: preview the current character's live bars, so the save
  -- checkboxes have rows to act on before any profile is selected
  if not window._getSelected() then
    window._barsGrid.Update(ns.Capture())
  end
  window:Show()
end

function ns:HideMainWindow()
  if window then window:Hide() end
end

-- Toggle convention: re-running the bare command on an open window closes it.
function ns:ToggleMainWindow()
  if window and window._widget:IsShown() then
    window:Hide()
  else
    self:Open()
  end
end

ns:registerCommand("", nil, function(self) self:ToggleMainWindow() end, "Toggle Action Bar Master")
