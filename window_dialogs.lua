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

  -- Commit a capture under `name`. `existing` (a profile entry) is overwritten
  -- in place — keeping its list position and identity (so a live selection
  -- stays valid, cf. #65); otherwise a new entry is FRONT-inserted at index 1,
  -- matching autosave's ordering and the "index 1 = most recent" convention.
  local function commitSave(name, existing)
    local profile = ns.Capture(parent._barsGrid.GetChecked())
    local encoded = ns.Encode(profile)
    -- partial captures blank class/spec; store nil so the list treats the
    -- entry as shared (visible to every class, [s] tag)
    local class = profile.class ~= "" and profile.class or nil
    local spec  = profile.spec  ~= "" and profile.spec  or nil
    if existing then
      existing.name, existing.char, existing.class, existing.spec, existing.encoded =
        name, profile.char, class, spec, encoded
    else
      table.insert(ns.db.profiles, 1, {
        name = name, char = profile.char, class = class, spec = spec, encoded = encoded,
      })
    end
    onSaved()
    dlg:Hide()
  end

  DoSave = function()
    local name = nameBox:Text()
    if name == "" then return end
    -- Saving into an existing (non-autosave) name overwrites that profile
    -- rather than silently duplicating it. Autosave entries are managed
    -- separately (keyed by char+spec) and are left alone here.
    local existing
    for _, p in ipairs(ns.db.profiles) do
      if not p.autosave and p.name == name then existing = p; break end
    end
    if existing then
      dlg._pendingName, dlg._pendingExisting = name, existing
      StaticPopup_Show("ABM_CONFIRM_OVERWRITE", name)
    else
      commitSave(name, nil)
    end
  end

  StaticPopupDialogs["ABM_CONFIRM_OVERWRITE"] = {
    text = "Overwrite profile '%s'?", button1 = YES, button2 = NO,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
    -- _pendingExisting holds the entry REFERENCE, so an autosave shifting
    -- indices during the confirm can't redirect the overwrite (cf. #65)
    OnAccept = function()
      commitSave(dlg._pendingName, dlg._pendingExisting)
      dlg._pendingName, dlg._pendingExisting = nil, nil
    end,
    OnCancel = function()
      dlg._pendingName, dlg._pendingExisting = nil, nil
    end,
  }

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
    -- grab focus on open so Ctrl+V works immediately. The Height fills the
    -- scroll viewport: an empty multiline editbox is only one line tall, so
    -- without it most of the box is dead to clicks and the user can't click in
    -- to focus it (then can't paste). (issue #81)
    autoFocus = true,
    fontObj   = GameFontHighlightSmall,
    position  = { Width = TXTDLG_W - PAD * 2 - 20, Height = 280 - ROW_H - PAD * 3 - BTN_H },
    OnEscapePressed = function() dlg:Hide() end,
    OnMouseUp       = function(self) self._widget:SetFocus() end,
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
