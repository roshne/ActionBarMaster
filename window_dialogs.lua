local _, ns = ...
local ui = ns.ui

local PAD      = 8
local ROW_H    = 22
local BTN_H    = 22
local DLG_W    = 280
local DLG_H    = 120
local TXTDLG_W = 420

---Build the Save Profile modal dialog.
---Inserts a new entry into ns.db.profiles and calls onSaved() on confirm.
---@param parent  table  LibNUI frame (the main window)
---@param onSaved fun()  called after a profile is saved (e.g. refresh the list)
---@return table  dialog frame (exposes ._nameBox for the Save button to focus)
function ns.BuildSaveDialog(parent, onSaved)
  local dlg = ui.TitleFrame:new{
    name     = "ActionBarMasterSaveDialog",
    title    = "Save Profile",
    special  = true,
    level    = 700,
    position = { Center = {}, Width = DLG_W, Height = DLG_H, Hide = true },
  }

  ui.Label:new{
    parent   = dlg,
    text     = "Profile name:",
    position = {
      TopLeft = { dlg.titlebar, ui.edge.BottomLeft, PAD, -PAD },
      Height  = ROW_H,
      Width   = DLG_W - PAD * 2,
    },
  }

  local DoSave
  local nameBox = ui.EditBox:new{
    parent   = dlg,
    position = {
      TopLeft = { dlg.titlebar, ui.edge.BottomLeft, PAD, -(PAD + ROW_H + 4) },
      Width   = DLG_W - PAD * 2,
      Height  = ROW_H,
    },
    OnEnterPressed  = function(self) DoSave() end,
    OnEscapePressed = function(self) dlg:Hide() end,
  }
  dlg._nameBox = nameBox

  DoSave = function()
    local name = nameBox:Text()
    if name == "" then return end
    local profile = ns.Capture()
    local encoded = ns.Encode(profile)
    table.insert(ns.db.profiles, {
      name = name, char = profile.char, class = profile.class,
      spec = profile.spec, encoded = encoded,
    })
    onSaved()
    dlg:Hide()
  end

  local okBtn = ui.Button:new{
    parent = dlg, template = "UIPanelButtonTemplate", glow = false,
    onClick  = DoSave,
    position = { Right = { dlg, ui.edge.Center, -2, 0 }, Bottom = { dlg, ui.edge.Bottom, 0, PAD }, Width = 60, Height = BTN_H },
  }
  okBtn:Text("OK")
  okBtn:TextAlign("CENTER")

  local cancelBtn = ui.Button:new{
    parent = dlg, template = "UIPanelButtonTemplate", glow = false,
    onClick  = function() dlg:Hide() end,
    position = { Left = { dlg, ui.edge.Center, 2, 0 }, Bottom = { dlg, ui.edge.Bottom, 0, PAD }, Width = 60, Height = BTN_H },
  }
  cancelBtn:Text("Cancel")
  cancelBtn:TextAlign("CENTER")

  return dlg
end

---Build the Export dialog (scrollable read-only text box).
---Caller sets dialog._box:Text(encoded) then calls dialog:Show().
---@param parent table  LibNUI frame
---@return table  dialog frame (exposes ._box)
function ns.BuildExportDialog(parent)
  local dlg = ui.TitleFrame:new{
    name = "ActionBarMasterExportDlg", title = "Export",
    special = true, level = 700,
    position = { Center = {}, Width = TXTDLG_W, Height = 280, Hide = true },
  }
  local scroll = ui.ScrollFrame:new{
    parent = dlg,
    position = {
      TopLeft     = { dlg.titlebar, ui.edge.BottomLeft, PAD, -PAD },
      BottomRight = { dlg, ui.edge.BottomRight, -PAD, PAD + BTN_H + PAD },
    },
  }
  local box = ui.EditBox:new{
    parent = scroll, multiline = true, template = "",
    fontObj = GameFontHighlightSmall,
    position  = { Width = TXTDLG_W - PAD * 2 - 20 },
    OnEscapePressed = function() dlg:Hide() end,
    OnMouseUp       = function(self) self._widget:HighlightText(0, -1) end,
  }
  scroll:Child(box)
  dlg._box = box

  local closeBtn = ui.Button:new{
    parent = dlg, template = "UIPanelButtonTemplate", glow = false,
    onClick  = function() dlg:Hide() end,
    position = { Left = { dlg, ui.edge.Center, -40, 0 }, Bottom = { dlg, ui.edge.Bottom, 0, PAD }, Width = 80, Height = BTN_H },
  }
  closeBtn:Text("Close")
  closeBtn:TextAlign("CENTER")

  return dlg
end

---Build the Import dialog (scrollable text input with Import/Close buttons).
---Decodes the pasted text and passes the profile to onImport on confirm.
---@param parent   table  LibNUI frame
---@param onImport fun(profile: table)  called with the decoded profile
---@return table  dialog frame (exposes ._box)
function ns.BuildImportDialog(parent, onImport)
  local dlg = ui.TitleFrame:new{
    name = "ActionBarMasterImportDlg", title = "Import",
    special = true, level = 700,
    position = { Center = {}, Width = TXTDLG_W, Height = 280, Hide = true },
  }
  local scroll = ui.ScrollFrame:new{
    parent = dlg,
    position = {
      TopLeft     = { dlg.titlebar, ui.edge.BottomLeft, PAD, -PAD },
      BottomRight = { dlg, ui.edge.BottomRight, -PAD, PAD + BTN_H + PAD },
    },
  }
  local box = ui.EditBox:new{
    parent = scroll, multiline = true, template = "",
    fontObj   = GameFontHighlightSmall,
    position  = { Width = TXTDLG_W - PAD * 2 - 20 },
    OnEscapePressed = function() dlg:Hide() end,
  }
  scroll:Child(box)
  dlg._box = box

  local impBtn = ui.Button:new{
    parent = dlg, template = "UIPanelButtonTemplate", glow = false,
    onClick = function()
      local profile, err = ns.Decode(box._widget:GetText())
      if not profile then ns.Print("Import failed: " .. (err or "?")); return end
      dlg:Hide()
      onImport(profile)
    end,
    position = { Right = { dlg, ui.edge.Center, -2, 0 }, Bottom = { dlg, ui.edge.Bottom, 0, PAD }, Width = 80, Height = BTN_H },
  }
  impBtn:Text("Import")
  impBtn:TextAlign("CENTER")

  local closeBtn = ui.Button:new{
    parent = dlg, template = "UIPanelButtonTemplate", glow = false,
    onClick  = function() dlg:Hide() end,
    position = { Left = { dlg, ui.edge.Center, 2, 0 }, Bottom = { dlg, ui.edge.Bottom, 0, PAD }, Width = 80, Height = BTN_H },
  }
  closeBtn:Text("Close")
  closeBtn:TextAlign("CENTER")

  return dlg
end
