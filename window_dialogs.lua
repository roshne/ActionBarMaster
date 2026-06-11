local _, ns = ...
local ui = ns.ui

local PAD      = 8
local ROW_H    = 22
local BTN_H    = 22
local DLG_W    = 280
local DLG_H    = 140
local TXTDLG_W = 420

---Build the Save Profile modal dialog.
---Captures with the grid's checkbox filter: excluding any bar produces a
---partial, class/spec-agnostic "shared" profile (see ns.Capture). Inserts a
---new entry into ns.db.profiles and calls onSaved() on confirm.
---@param parent  table  LibNUI frame (the main window; reads parent._barsGrid)
---@param onSaved fun()  called after a profile is saved (e.g. refresh the list)
---@return table  dialog frame (exposes ._nameBox to focus, ._note to describe scope)
function ns.BuildSaveDialog(parent, onSaved)
  -- Dialogs are NOT `special`: CloseSpecialWindows hides every visible special
  -- frame at once, so Escape would close the main window along with the dialog.
  local dlg = ui.TitleFrame:new{
    name     = "ActionBarMasterSaveDialog",
    title    = "Save Profile",
    level    = 700,
    position = { Center = {}, Width = DLG_W, Height = DLG_H, Hide = true },
  }
  ns.CaptureEscape(dlg)

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

  -- scope note ("Saving all bars" / "Saving N of M bars — shared");
  -- text set by the window's Save button from the current checkbox state
  dlg._note = ui.Label:new{
    parent   = dlg,
    fontObj  = "GameFontHighlightSmall",
    position = {
      TopLeft = { dlg.titlebar, ui.edge.BottomLeft, PAD, -(PAD + ROW_H + 4 + ROW_H + 4) },
      Width   = DLG_W - PAD * 2,
      Height  = ROW_H,
    },
  }

  DoSave = function()
    local name = nameBox:Text()
    if name == "" then return end
    local profile = ns.Capture(parent._barsGrid.GetChecked())
    local encoded = ns.Encode(profile)
    table.insert(ns.db.profiles, {
      name    = name,
      char    = profile.char,
      -- partial captures blank class/spec; store nil so the list treats the
      -- entry as shared (visible to every class, [s] tag)
      class   = profile.class ~= "" and profile.class or nil,
      spec    = profile.spec  ~= "" and profile.spec  or nil,
      encoded = encoded,
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
    level = 700,  -- not special; Escape handled by ns.CaptureEscape
    position = { Center = {}, Width = TXTDLG_W, Height = 280, Hide = true },
  }
  ns.CaptureEscape(dlg)
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
    level = 700,  -- not special; Escape handled by ns.CaptureEscape
    position = { Center = {}, Width = TXTDLG_W, Height = 280, Hide = true },
  }
  ns.CaptureEscape(dlg)
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
