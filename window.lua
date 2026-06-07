local _, ns = ...
local ui = ns.ui

local WIN_W   = 720
local WIN_H   = 520
local LIST_W  = 240
local FILTER_W = 130
local PAD     = 8
local ROW_H   = 22
local BTN_H   = 22

local window = nil

local function CreateWindow()
  local f = ui.TitleFrame:new{
    name     = "ActionBarMasterWindow",
    title    = "Action Bar Master",
    special  = true,
    level    = 600,
    position = { Center = {-75, 150}, Width = WIN_W, Height = WIN_H },
  }

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

  ui.Label:new{
    parent   = f,
    text     = "Contents",
    position = {
      TopLeft  = { f.titlebar, ui.edge.BottomLeft, PAD + LIST_W + PAD + FILTER_W + PAD, -PAD },
      TopRight = { f.titlebar, ui.edge.BottomRight, -PAD, -PAD },
      Height   = ROW_H,
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
    if p then f._textbox:Text(p.encoded or "") end
  end

  local _, refreshList, getSelected, setSelected, setClassFilter = ns.BuildProfileList(listPanel, OnSelect)
  f._refreshList = refreshList

  ns.BuildClassFilter(f, {
    TopLeft = { f.titlebar, ui.edge.BottomLeft, PAD + LIST_W + PAD, -PAD },
    Width   = FILTER_W,
    Height  = ROW_H,
  }, function(key) setClassFilter(key) end)

  -- ── Right panel (text area) ──────────────────────────────────────────────
  local textScroll = ui.ScrollFrame:new{
    parent   = f,
    position = {
      TopLeft     = { profilesHeader, ui.edge.BottomLeft, LIST_W + PAD, -2 },
      BottomRight = { f, ui.edge.BottomRight, -PAD, PAD + BTN_H + PAD + ROW_H + PAD },
    },
  }

  local textW = WIN_W - LIST_W - PAD * 3 - 20
  local eb = ui.EditBox:new{
    parent    = textScroll,
    multiline = true,
    template  = "",
    fontObj   = GameFontHighlightSmall,
    position  = { Width = textW },
    OnEscapePressed = function(self) f:Hide() end,
    OnMouseUp       = function(self) self._widget:HighlightText(0, -1) end,
  }
  textScroll:Child(eb)
  f._textbox = eb

  -- ── Save dialog (LibNUI, avoids StaticPopup editbox quirks) ─────────────
  local DLG_W, DLG_H = 280, 120
  local saveDialog = ui.TitleFrame:new{
    name     = "ActionBarMasterSaveDialog",
    title    = "Save Profile",
    special  = true,
    level    = 700,
    position = { Center = {}, Width = DLG_W, Height = DLG_H, Hide = true },
  }

  ui.Label:new{
    parent   = saveDialog,
    text     = "Profile name:",
    position = {
      TopLeft = { saveDialog.titlebar, ui.edge.BottomLeft, PAD, -PAD },
      Height  = ROW_H,
      Width   = DLG_W - PAD * 2,
    },
  }

  local DoSave  -- forward declaration so nameBox closure can reference it
  local nameBox = ui.EditBox:new{
    parent   = saveDialog,
    position = {
      TopLeft = { saveDialog.titlebar, ui.edge.BottomLeft, PAD, -(PAD + ROW_H + 4) },
      Width   = DLG_W - PAD * 2,
      Height  = ROW_H,
    },
    OnEnterPressed  = function(self) DoSave() end,
    OnEscapePressed = function(self) saveDialog:Hide() end,
  }
  saveDialog._nameBox = nameBox

  DoSave = function()
    local name = nameBox:Text()
    if name == "" then return end
    local profile = ns.Capture()
    local encoded = ns.Encode(profile)
    eb:Text(encoded)
    table.insert(ns.db.profiles, {
      name = name, char = profile.char, class = profile.class,
      spec = profile.spec, encoded = encoded,
    })
    refreshList()
    saveDialog:Hide()
  end

  ui.Button:new{
    parent   = saveDialog, onClick = DoSave,
    position = { Right = { saveDialog, ui.edge.Center, -2, 0 }, Bottom = { saveDialog, ui.edge.Bottom, 0, PAD }, Width = 60, Height = BTN_H },
  }
  ui.Label:new{
    parent   = saveDialog, text = "OK",
    position = { Right = { saveDialog, ui.edge.Center, -2 + 4, 0 }, Bottom = { saveDialog, ui.edge.Bottom, 0, PAD }, Width = 60, Height = BTN_H },
  }
  ui.Button:new{
    parent   = saveDialog, onClick = function() saveDialog:Hide() end,
    position = { Left = { saveDialog, ui.edge.Center, 2, 0 }, Bottom = { saveDialog, ui.edge.Bottom, 0, PAD }, Width = 60, Height = BTN_H },
  }
  ui.Label:new{
    parent   = saveDialog, text = "Cancel",
    position = { Left = { saveDialog, ui.edge.Center, 2 + 4, 0 }, Bottom = { saveDialog, ui.edge.Bottom, 0, PAD }, Width = 60, Height = BTN_H },
  }

  -- ── Bottom buttons ───────────────────────────────────────────────────────
  -- Left group: Autosave Now(90) + Save/Load/Delete(60ea) with 4px gaps
  -- Right group: Export/Import(60ea) separated from left by 20px
  local LX = { PAD, PAD+114, PAD+114+64, PAD+114+128 }
  local RX = { PAD+114+128+80, PAD+114+128+80+64 }

  local btnDefs = {
    {
      label = "Autosave Now",
      x     = LX[1],
      w     = 110,
      fn    = function()
        ns.AutoSave()
        refreshList()
      end,
    },
    {
      label = "Save",
      x     = LX[2],
      fn    = function()
        saveDialog:Show()
        saveDialog._nameBox:Text("")
        saveDialog._nameBox._widget:SetFocus()
      end,
    },
    {
      label = "Load",
      x     = LX[3],
      fn    = function()
        local i = getSelected()
        if not i then ns.Print("Select a profile first."); return end
        local p = ns.db.profiles[i]
        local profile, err = ns.Decode(p.encoded or "")
        if not profile then ns.Print("Load failed: " .. (err or "?")); return end
        f._pendingProfile = profile
        StaticPopup_Show("ABM_CONFIRM_IMPORT", p.name)
      end,
    },
    {
      label = "Delete",
      x     = LX[4],
      fn    = function()
        local i = getSelected()
        if not i then ns.Print("Select a profile first."); return end
        local p = ns.db.profiles[i]
        f._pendingDelete = i
        StaticPopup_Show("ABM_CONFIRM_DELETE", p.name)
      end,
    },
    {
      label = "Export",
      x     = RX[1],
      fn    = function()
        local profile = ns.Capture()
        local encoded = ns.Encode(profile)
        eb:Text(encoded)
        eb._widget:HighlightText(0, -1)
      end,
    },
    {
      label = "Import",
      x     = RX[2],
      fn    = function()
        local text = eb._widget:GetText()
        local profile, err = ns.Decode(text)
        if not profile then
          ns.Print("Import failed: " .. (err or "unknown error"))
          return
        end
        f._pendingProfile = profile
        StaticPopup_Show("ABM_CONFIRM_IMPORT", profile.char .. " / " .. profile.spec)
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

  -- StaticPopup callbacks reference f and eb via upvalue closure
  StaticPopupDialogs["ABM_CONFIRM_DELETE"] = {
    text         = "Delete '%s'?",
    button1      = DELETE,
    button2      = CANCEL,
    timeout      = 0,
    whileDead    = 1,
    hideOnEscape = 1,
    OnAccept = function(self)
      local i = f._pendingDelete
      if i and ns.db.profiles[i] then
        table.remove(ns.db.profiles, i)
        setSelected(nil)
        refreshList()
        eb:Text("")
      end
      f._pendingDelete = nil
    end,
    OnCancel = function(self)
      f._pendingDelete = nil
    end,
  }

  StaticPopupDialogs["ABM_CONFIRM_IMPORT"] = {
    text         = "Restore bars from '%s'?",
    button1      = ACCEPT,
    button2      = CANCEL,
    timeout      = 0,
    whileDead    = 1,
    hideOnEscape = 1,
    OnAccept = function(self)
      if f._pendingProfile then
        ns.Restore(f._pendingProfile)
        f._pendingProfile = nil
      end
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
