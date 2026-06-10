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

  local function OnSelect(i)
    local p = ns.db.profiles[i]
    if not p then f._barsGrid.Update(nil); return end
    local profile, err = ns.Decode(p.encoded or "")
    if err then ns.Print("Decode error: " .. err) end
    f._barsGrid.Update(profile)
  end

  local _, refreshList, getSelected, setSelected, setClassFilter = ns.BuildProfileList(listPanel, OnSelect)
  f._refreshList = refreshList

  ns.BuildClassFilter(f, {
    TopLeft = { f.titlebar, ui.edge.BottomLeft, PAD + LIST_W + PAD, -PAD },
    Width   = FILTER_W,
    Height  = ROW_H,
  }, function(key) setClassFilter(key) end)

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
    StaticPopup_Show("ABM_CONFIRM_IMPORT", profile.char .. " / " .. profile.spec)
  end)

  -- ── Bottom buttons ───────────────────────────────────────────────────────
  local W1, W2, BSEP, GSEP = 110, 60, 4, 20  -- wide btn, std btn, btn gap, group gap
  local lx1 = PAD
  local lx2 = lx1 + W1 + BSEP
  local lx3 = lx2 + W2 + BSEP
  local lx4 = lx3 + W2 + BSEP
  local rx1 = lx4 + W2 + GSEP
  local rx2 = rx1 + W2 + BSEP
  local LX = { lx1, lx2, lx3, lx4 }
  local RX = { rx1, rx2 }

  local btnDefs = {
    {
      label = "Autosave Now", x = LX[1], w = 110,
      fn = function() ns.AutoSave(); refreshList() end,
    },
    {
      label = "Save", x = LX[2],
      fn = function()
        saveDialog:Show()
        saveDialog._nameBox:Text("")
        saveDialog._nameBox._widget:SetFocus()
      end,
    },
    {
      label = "Load", x = LX[3],
      fn = function()
        local i = getSelected()
        if not i then ns.Print("Select a profile first."); return end
        local p = ns.db.profiles[i]
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
        local i = getSelected()
        if not i then ns.Print("Select a profile first."); return end
        f._pendingDelete = i
        StaticPopup_Show("ABM_CONFIRM_DELETE", ns.db.profiles[i].name)
      end,
    },
    {
      label = "Export", x = RX[1],
      fn = function()
        local encoded = ns.Encode(ns.Capture())
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
      local i = f._pendingDelete
      if i and ns.db.profiles[i] then
        table.remove(ns.db.profiles, i)
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
  window:Show()
end

ns:registerCommand("", nil, function(self) self:Open() end, "Open Action Bar Master")
