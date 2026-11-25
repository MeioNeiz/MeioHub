-- One list of the Meio addons installed (.toc Author MeioNeiz or Category Meio): what
-- each does, its Settings panel, its /cmd help and slash command; then the released ones
-- not installed. In the /meiohub window and in Esc > Options > AddOns > MeioHub. Only reads
-- other addons, never changes them.
local ADDON, ns = ...

local PREFIX = "|cffb090ffMeioHub:|r "
local AUTHOR, CATEGORY = "MeioNeiz", "Meio"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ROW_H, ICON = 34, 26
local WIDTH, HEIGHT = 580, 452
local TITLE_H, FRAME_PAD, PAD = 24, 6, 6
local SLASH_W, SETTINGS_W, HELP_W = 96, 66, 46

-- Released Meio addons, listed when not installed: name, listing title, icon, what it does
local RELEASED = {
  { "MeioAlts", "Meio Alts", "INV_Misc_GroupNeedMore",
    "Gold, rested XP and mail for every character, in one list beside the Esc menu" },
  { "MeioAutoRank", "Meio Auto Rank", "INV_Misc_Book_09",
    "New spell ranks go on your bars by themselves; low ranks you chose stay" },
  { "MeioAutoRunTurn", "Meio Auto Run Turn", "Ability_Rogue_Sprint",
    "Turn with A and D while autorunning; they strafe again when you stop" },
  { "MeioBags", "Meio Bags", "INV_Misc_Bag_08",
    "One key deletes your cheapest junk when bags are full; vendors buy the rest" },
  { "MeioBiSExtras", "Meio BiS Extras", "INV_Chest_Cloth_17",
    "Forever Leveling BiS tooltips compare without Shift; Alt-click for Wowhead" },
  { "MeioBuffThanks", "Meio Buff Thanks", "Spell_Holy_WordFortitude",
    "Thanks players who buff you with a whisper, picked from your own lines" },
  { "MeioDPS", "Meio DPS", "Spell_Shadow_ShadowBolt",
    "Damage and DPS on tooltips and action buttons, plus best rank per mana" },
  { "MeioFixes", "Meio Fixes", "INV_Misc_Wrench_01",
    "Create Auction works again on trade goods; no more auction house Lua errors" },
  { "MeioFlareFixes", "Meio Flare Fixes", "INV_Misc_Wrench_01",
    "Fixes FlareUI chat tabs eating clicks on bank, vendor and quest windows" },
  { "MeioFlareQuestie", "Meio Flare Questie", "INV_Misc_Map_01",
    "Questie in FlareUI's quest tracker: yards to each quest and turn-in NPCs" },
  { "MeioFlightTimes", "Meio Flight Times", "Ability_Mount_Gryphon_01",
    "Flight times on the flight map, even for routes you've never flown" },
  { "MeioMail", "Meio Mail", "INV_Letter_15",
    "Sent mail history beside the mailbox: who to, items, gold and when" },
  { "MeioMap", "Meio Map", "INV_Misc_Map_01",
    "Zone level range and fishing skill when you hover the world map" },
  { "MeioMeterHover", "Meio Meter Hover", "INV_Misc_Spyglass_02",
    "Hover a player in Blizzard's damage meter to see their spells, no clicking" },
  { "MeioNextStop", "Meio Next Stop", "Ability_Mount_Gryphon_01",
    "Get off a flight early: a button that lands you at the next flight master" },
  { "MeioPets", "Meio Pets", "Ability_Hunter_MendPet",
    "Warns hunters and warlocks when their pet is low, dead, or not back after a fight" },
  { "MeioPlates", "Meio Plates", "Ability_DualWield",
    "Shows on enemy nameplates how many hits to kill, counting your DoTs and pet" },
  { "MeioQoL", "Meio QoL", "INV_Misc_Gear_01",
    "Tops up water and reagents at vendors, skips NPC chat, loots at once" },
  { "MeioShards", "Meio Shards", "INV_Misc_Gem_Amethyst_02",
    "One key deletes the Soul Shards over your cap or soul bag, never in combat" },
  { "MeioSpikeCheck", "Meio Spike Check", "INV_Misc_PocketWatch_02",
    "Finds out which addon is behind the stutters and freezes in your game" },
  { "MeioStats", "Meio Stats", "INV_Misc_PocketWatch_01",
    "XP per hour, time to level, quest drop luck and gold earned, in one window" },
  { "MeioTooltipFold", "Meio Tooltip Fold", "INV_Misc_Note_02",
    "Shorter item tooltips: Pawn and RestedXP lines move into Blizzard's own" },
  { "MeioTrainerCompare", "Meio Trainer Compare", "Trade_Tailoring",
    "Your equipped gear beside profession trainer recipes, like any other item" },
  { "MeioTSMBrowse", "Meio TSM Browse", "INV_Scroll_03",
    "Browse TSM by category like the normal AH; recipe tooltips show skill-ups" },
  { "Meionomics", "Meionomics", "INV_Misc_Coin_01",
    "Cheapest skill-ups and best-profit crafts, plus AH buy and sell help" },
}

local db, window, category

local function Print(msg) print(PREFIX .. msg) end
ns.Print = Print

local function Plain(s)
  if type(s) ~= "string" then return nil end
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Norm(s) return (s:upper():gsub("[^%w]", "")) end

------------------------------------------------------------------------------ discovery

local function Commands(key)
  local out, i = {}, 1
  while type(_G["SLASH_" .. key .. i]) == "string" do
    out[#out + 1] = _G["SLASH_" .. key .. i]
    i = i + 1
  end
  return out
end

-- SlashCmdList keys, and which addon set each: an addon's write taints the entry with its
-- name, so issecurevariable says whose it is (the workbench can't, hence the name match)
local function SlashIndex()
  local byOwner, keys = {}, {}
  for key in pairs(SlashCmdList) do
    if type(key) == "string" and type(_G["SLASH_" .. key .. "1"]) == "string" then
      keys[#keys + 1] = key
      local secure, owner = issecurevariable(SlashCmdList, key)
      if not secure and owner then
        byOwner[owner] = byOwner[owner] or {}
        table.insert(byOwner[owner], key)
      end
    end
  end
  table.sort(keys)
  for _, owned in pairs(byOwner) do table.sort(owned) end
  return byOwner, keys
end

-- The addon's own key: named after it (MEIOBISEXTRASORDER for MeioBiSExtras),
-- shortest first; else the first key it owns
local function FindSlash(name, byOwner, keys)
  local want, owned, best = Norm(name), byOwner[name], nil
  for _, key in ipairs(owned or keys) do
    if Norm(key):sub(1, #want) == want and (not best or #key < #best) then best = key end
  end
  return best or (owned and owned[1])
end

-- Our addons name their Settings category exactly their Title
local function FindCategory(title)
  if not (SettingsPanel and SettingsPanel.GetAllCategories) then return end
  for _, cat in ipairs(SettingsPanel:GetAllCategories() or {}) do
    if Plain(cat:GetName()) == title then return cat end
  end
end

local function Collect()
  local byOwner, keys = SlashIndex()
  local list = {}
  for i = 1, C_AddOns.GetNumAddOns() do
    local name, title, notes, _, reason = C_AddOns.GetAddOnInfo(i)
    local function meta(k) return C_AddOns.GetAddOnMetadata(name, k) end
    local ours = meta("Author") == AUTHOR or meta("Category") == CATEGORY
    if name and name ~= ADDON and ours then
      local a = {
        name = name, title = Plain(title) or name, notes = Plain(notes) or "",
        version = meta("Version"), icon = meta("IconTexture"), atlas = meta("IconAtlas"),
        loaded = C_AddOns.IsAddOnLoaded(name), reason = reason,
      }
      if a.loaded then
        a.slash = FindSlash(name, byOwner, keys)
        a.category = FindCategory(a.title)
      end
      list[#list + 1] = a
    end
  end
  table.sort(list, function(x, y) return x.title:lower() < y.title:lower() end)
  return list
end
ns.Collect = Collect

local function NotInstalled(installed)
  local have, out = {}, {}
  for _, a in ipairs(installed) do have[a.name] = true end
  for _, r in ipairs(RELEASED) do
    if not have[r[1]] then
      out[#out + 1] = {
        name = r[1], title = r[2], icon = "Interface\\Icons\\" .. r[3], notes = r[4],
        missing = true,
      }
    end
  end
  table.sort(out, function(x, y) return x.title:lower() < y.title:lower() end)
  return out
end

------------------------------------------------------------------------------ actions

-- The addon's own handler, as typing "/cmd help" would call it; errors still reach BugSack
local function RunHelp(a)
  local fn = a.slash and SlashCmdList[a.slash]
  if not fn then return end
  local editBox = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
  xpcall(fn, geterrorhandler(), "help", editBox)
end

local function OpenSettings(cat)
  if window and window:IsShown() then window:Hide() end
  Settings.OpenToCategory(cat:GetID())
end

------------------------------------------------------------------------------ list

local function ShowTip(owner, title, text)
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  GameTooltip:AddLine(title)
  if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
  GameTooltip:Show()
end

local function RowTooltip(row)
  local a = row.addon
  if a.header then return end
  -- beside the list, clear of the window's close button and the row's buttons
  GameTooltip:SetOwner(row, "ANCHOR_NONE")
  GameTooltip:SetPoint("TOPLEFT", row, "TOPRIGHT", 36, 0)
  GameTooltip:AddDoubleLine(a.title, a.version, nil, nil, nil, 0.6, 0.6, 0.6)
  if a.notes ~= "" then GameTooltip:AddLine(a.notes, 1, 1, 1, true) end
  local newer = ns.Newer and ns.Newer(a)
  if newer then
    GameTooltip:AddLine(("Version %s is out (seen on %s). Update with CurseForge or Wago.")
      :format(newer.version, newer.from), 0.25, 1, 0.25, true)
  end
  local errs = ns.Errors and ns.Errors(a)
  if errs then
    GameTooltip:AddLine(("%d Lua %s this session:"):format(errs.count,
      errs.count == 1 and "error" or "errors"), 1, 0.3, 0.3)
    GameTooltip:AddLine(errs.message, 1, 0.6, 0.6, true)
    local link = ns.IssuesLink(a.name)
    local sack = C_AddOns.IsAddOnLoaded("BugSack") and "Full report: /bugsack. " or ""
    local report = link and ("Report it at " .. link .. ".") or ""
    GameTooltip:AddLine(sack .. report, 0.6, 0.6, 0.6, true)
  end
  if a.slash then
    local cmds = table.concat(Commands(a.slash), ", ")
    GameTooltip:AddDoubleLine("Commands", cmds, nil, nil, nil, 1, 1, 1)
  end
  if a.category then
    GameTooltip:AddDoubleLine("Settings", "Esc > Options > AddOns > " .. a.title,
      nil, nil, nil, 1, 1, 1)
  end
  if a.missing then
    local where = ('Not installed. Search "%s" on CurseForge or Wago.'):format(a.title)
    GameTooltip:AddLine(where, 0.6, 0.6, 0.6, true)
  elseif not a.loaded then
    local why = a.reason and _G["ADDON_" .. a.reason]
    GameTooltip:AddLine("Not loaded" .. (why and (": " .. why:lower()) or "")
      .. ". Tick it in the AddOns list, then reload.", 1, 0.5, 0.5, true)
  end
  GameTooltip:Show()
end

local function SmallButton(row, text, w)
  local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  b:SetSize(w, 20)
  b:SetText(text)
  local fs = b:GetFontString()
  if fs then fs:SetFontObject("GameFontNormalSmall") end
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

local function Row(L, i)
  if L.rows[i] then return L.rows[i] end
  local row = CreateFrame("Frame", nil, L.child)
  row.addon = nil
  row:SetHeight(ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row:SetPoint("RIGHT")
  row:EnableMouse(true)
  local stripe = row:CreateTexture(nil, "BACKGROUND")
  stripe:SetAllPoints()
  stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ICON, ICON)
  row.icon:SetPoint("LEFT", 4, 0)
  row.help = SmallButton(row, "Help", HELP_W)
  row.help:SetPoint("RIGHT", -4, 0)
  row.help:SetScript("OnClick", function() RunHelp(row.addon) end)
  row.help:SetScript("OnEnter", function(self)
    local cmd = Commands(row.addon.slash)[1] or ""
    ShowTip(self, cmd .. " help", "Prints " .. row.addon.title .. "'s commands in chat.")
  end)
  row.settings = SmallButton(row, "Settings", SETTINGS_W)
  row.settings:SetPoint("RIGHT", row.help, "LEFT", -4, 0)
  row.settings:SetScript("OnClick", function() OpenSettings(row.addon.category) end)
  row.settings:SetScript("OnEnter", function(self)
    ShowTip(self, "Settings", "Opens Esc > Options > AddOns > " .. row.addon.title .. ".")
  end)
  row.slash = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  row.slash:SetPoint("RIGHT", -8, 0)
  row.slash:SetWidth(SLASH_W)
  row.slash:SetJustifyH("RIGHT")
  row.slash:SetWordWrap(false)
  row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 1)
  row.title:SetPoint("RIGHT", row.slash, "LEFT", -8, 0)
  row.title:SetJustifyH("LEFT")
  row.title:SetWordWrap(false)
  row.notes = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.notes:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
  row.notes:SetPoint("RIGHT", row.slash, "LEFT", -8, 0)
  row.notes:SetJustifyH("LEFT")
  row.notes:SetWordWrap(false)
  row:SetScript("OnEnter", RowTooltip)
  row:SetScript("OnLeave", GameTooltip_Hide)
  L.rows[i] = row
  return row
end

local function SetHeader(row)
  row.icon:Hide()
  row.title:SetText("More Meio addons")
  row.title:SetFontObject("GameFontNormal")
  row.notes:SetText("Not installed. Search for them on CurseForge or Wago.")
  row.notes:SetFontObject("GameFontDisableSmall")
  row.slash:SetText("")
  row.slash:ClearAllPoints()
  row.slash:SetPoint("RIGHT", -8, 0)
  row.settings:Hide()
  row.help:Hide()
end

local function SetRow(row, a)
  row.addon = a
  if a.header then return SetHeader(row) end
  row.icon:Show()
  if a.atlas then
    row.icon:SetAtlas(a.atlas)
  else
    row.icon:SetTexture(a.icon or FALLBACK_ICON)
  end
  row.icon:SetDesaturated(not (a.loaded or a.missing))
  row.icon:SetAlpha(a.loaded and 1 or 0.5)
  local version = a.version and ("  |cff999999" .. a.version .. "|r") or ""
  local newer = ns.Newer and ns.Newer(a)
  if newer then version = version .. "  |cff40ff40" .. newer.version .. " out|r" end
  local errs = ns.Errors and ns.Errors(a)
  if errs then
    version = version .. ("  |cffff5050%d %s|r"):format(errs.count,
      errs.count == 1 and "error" or "errors")
  end
  row.title:SetText(a.title .. version)
  row.title:SetFontObject(a.loaded and "GameFontNormal" or "GameFontDisable")
  row.notes:SetText(a.notes)
  row.notes:SetFontObject(a.loaded and "GameFontHighlightSmall" or "GameFontDisableSmall")
  if a.loaded then
    row.slash:SetText(a.slash and Commands(a.slash)[1] or "")
  elseif a.missing then
    row.slash:SetText("|cff999999not installed|r")
  else
    row.slash:SetText("|cff999999not loaded|r")
  end
  row.settings:SetShown(a.category ~= nil)
  row.help:SetShown(a.slash ~= nil)
  -- no buttons: the label moves right so the notes get the buttons' room
  row.slash:ClearAllPoints()
  if a.category or a.slash then
    row.slash:SetPoint("RIGHT", row.settings, "LEFT", -8, 0)
  else
    row.slash:SetPoint("RIGHT", -8, 0)
  end
end

local function Fill(L)
  local installed = Collect()
  local data = { unpack(installed) }
  local more = NotInstalled(installed)
  if #more > 0 then
    data[#data + 1] = { header = true }
    for _, a in ipairs(more) do data[#data + 1] = a end
  end
  L.child:SetWidth(math.max(1, L.scroll:GetWidth()))
  for i, a in ipairs(data) do
    local row = Row(L, i)
    SetRow(row, a)
    row:Show()
  end
  for i = #data + 1, #L.rows do L.rows[i]:Hide() end
  L.child:SetHeight(math.max(1, #data * ROW_H))
  local loaded = 0
  for _, a in ipairs(installed) do if a.loaded then loaded = loaded + 1 end end
  if #installed == 0 then
    L.count:SetText("No other Meio addons installed yet. Hover one for what it does.")
  else
    local fmt = "%d Meio %s installed, %d loaded. Hover one for details."
    L.count:SetFormattedText(fmt, #installed, #installed == 1 and "addon" or "addons", loaded)
  end
end

-- A scrolling list under `top` (a font string for the count line), filling `parent`
local function NewList(parent, top, inset)
  local L = { rows = {} }
  L.count = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  L.count:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -6)
  L.scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  L.scroll:SetPoint("TOPLEFT", L.count, "BOTTOMLEFT", 0, -6)
  L.scroll:SetPoint("BOTTOMRIGHT", -inset - 22, inset)
  L.child = CreateFrame("Frame", nil, L.scroll)
  L.child:SetSize(1, 1)
  L.scroll:SetScrollChild(L.child)
  L.scroll:SetScript("OnSizeChanged", function(_, w) L.child:SetWidth(math.max(1, w)) end)
  return L
end

------------------------------------------------------------------------------ window

local function SavePosition()
  local point, _, relPoint, x, y = window:GetPoint(1)
  db.pos = { point, relPoint, x, y }
end

local function Place()
  window:ClearAllPoints()
  local p = db.pos --[[@as any]]
  if p then
    window:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    window:SetPoint("CENTER")
  end
end

local function CreateWindow()
  local f = CreateFrame("Frame", "MeioHubFrame", UIParent, "ButtonFrameTemplate")
  window = f
  ButtonFrameTemplate_HidePortrait(f)
  if f.SetTitle then f:SetTitle("MeioHub") end
  f:SetSize(WIDTH, HEIGHT)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  if f.SetDontSavePosition then f:SetDontSavePosition(true) end
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
  end)
  tinsert(UISpecialFrames, f:GetName())
  f.Inset:ClearAllPoints()
  f.Inset:SetPoint("TOPLEFT", FRAME_PAD, -TITLE_H)
  f.Inset:SetPoint("BOTTOMRIGHT", -FRAME_PAD, FRAME_PAD)
  local anchor = f.Inset:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  anchor:SetPoint("TOPLEFT", PAD, -PAD)
  anchor:SetText("Meio addons")
  local L = NewList(f.Inset, anchor, PAD)
  f.list = L
  f:SetScript("OnShow", function() Fill(L) end)
  f:Hide()
  Place()
end

function ns.Refill()
  if window and window:IsShown() then Fill(window.list) end
end

local function Toggle()
  if not window then CreateWindow() end
  window:SetShown(not window:IsShown())
end

local function ResetPosition()
  db.pos = nil
  if window then Place() end
end

------------------------------------------------------------------------------ settings

local function RegisterSettings()
  if category or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  local panel = CreateFrame("Frame")
  local head = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  head:SetPoint("TOPLEFT", 7, -22)
  head:SetText("MeioHub")
  local L = NewList(panel, head, 10)
  panel.list = L
  panel:SetScript("OnShow", function() Fill(L) end)
  category = Settings.RegisterCanvasLayoutCategory(panel, "MeioHub")
  Settings.RegisterAddOnCategory(category)
end

local function OpenOwnSettings()
  if not category then return false end
  if window then window:Hide() end
  Settings.OpenToCategory(category:GetID())
  return true
end

------------------------------------------------------------------------------ slash, events

local HELP = {
  "your Meio addons in one list, with their settings, help and slash commands",
  "  |cffffd100/meiohub|r - open or close the list (also |cffffd100/mh|r)",
  "  |cffffd100/meiohub reset|r - put the window back",
  "  |cffffd100/meiohub versions on||off|r - tell me when a Meio addon has a newer version",
  "  |cffffd100/meiohub errors on||off|r - say which Meio addon a Lua error came from",
  "  Settings: Esc > Options > AddOns > MeioHub (|cffffd100/meiohub settings|r)",
}

local function Help()
  Print(HELP[1])
  for i = 2, #HELP do print(HELP[i]) end
end

SLASH_MEIOHUB1 = "/meiohub"
SLASH_MEIOHUB2 = "/mh"
SlashCmdList.MEIOHUB = function(msg)
  local cmd = strtrim(msg or ""):lower()
  if cmd == "" then
    Toggle()
  elseif cmd == "reset" then
    ResetPosition()
    Print("window back in the middle of the screen")
  elseif cmd == "settings" or cmd == "options" then
    if not OpenOwnSettings() then Help() end
  elseif cmd == "versions on" or cmd == "versions off" then
    db.versions = cmd == "versions on"
    Print("newer version notes " .. (db.versions and "on" or "off"))
  elseif cmd == "errors on" or cmd == "errors off" then
    db.errors = cmd == "errors on"
    Print("Meio addon error notes " .. (db.errors and "on" or "off"))
  elseif cmd == "help" or cmd == "?" then
    Help()
  else
    Print(('unknown command "%s"'):format(cmd))
    Help()
  end
end

function MeioHub_OnAddonCompartmentClick() Toggle() end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    MeioHubDB = MeioHubDB or {}
    db = MeioHubDB
    if db.versions == nil then db.versions = true end
    if db.errors == nil then db.errors = true end
    ns.db = db
  elseif event == "PLAYER_LOGIN" then
    local ok, err = pcall(RegisterSettings)
    if not ok then geterrorhandler()(err) end
  end
end)
