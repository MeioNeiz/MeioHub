-- Newer version notes: each MeioHub tells its guild and group which Meio addon versions it
-- has (one hidden addon message, no chat); a Meio addon someone else has newer gets one chat
-- line, once per version, and a mark on its row. Off: /meiohub versions off (stops sending too).
local ADDON, ns = ...

local PREFIX = "MeioHub"
local TAG = "V1 "
local MAX_MSG = 250 -- addon messages are capped at 255 bytes
local LOGIN_DELAY, GROUP_GAP = 10, 60
local issecret = issecretvalue or function() return false end
local canaccess = canaccessvalue or function() return true end

local seen = {} -- addon name -> { version, from }
local lastGroupSend = -GROUP_GAP

local function Readable(v) return v ~= nil and not issecret(v) and canaccess(v) end

local function Parts(v)
  v = type(v) == "string" and v:match("^v?(%d+[%.%d]*)$")
  if not v then return end
  local out = {}
  for n in v:gmatch("%d+") do out[#out + 1] = tonumber(n) end
  return out
end

-- true when version a is newer than b; unknown or odd versions never are
local function IsNewer(a, b)
  local x, y = Parts(a), Parts(b)
  if not (x and y) then return false end
  for i = 1, math.max(#x, #y) do
    local p, q = x[i] or 0, y[i] or 0
    if p ~= q then return p > q end
  end
  return false
end
ns.IsNewer = IsNewer

local function Mine()
  local out = {}
  for _, a in ipairs(ns.Collect()) do
    if Parts(a.version) then out[a.name] = a end
  end
  local own = C_AddOns.GetAddOnMetadata(ADDON, "Version")
  if Parts(own) then out[ADDON] = { name = ADDON, title = ADDON, version = own } end
  return out
end

function ns.Newer(a)
  local s = a and a.version and seen[a.name]
  if s and IsNewer(s.version, a.version) then return s end
end

local function Messages()
  local pairs_ = {}
  for name, a in pairs(Mine()) do pairs_[#pairs_ + 1] = name .. "=" .. a.version end
  table.sort(pairs_)
  local out, cur = {}, TAG
  for _, p in ipairs(pairs_) do
    if #cur + #p + 1 > MAX_MSG then
      out[#out + 1] = cur
      cur = TAG
    end
    cur = cur .. (cur == TAG and "" or ",") .. p
  end
  if cur ~= TAG then out[#out + 1] = cur end
  return out
end

local function Send(channel)
  if not (ns.db and ns.db.versions and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  for _, msg in ipairs(Messages()) do
    -- refused in some instances and during encounters: next roster change tries again
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel)
  end
end

local function GroupChannel()
  if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  end
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
end

local function SendGroup()
  local channel = GroupChannel()
  if not channel or GetTime() - lastGroupSend < GROUP_GAP then return end
  lastGroupSend = GetTime()
  Send(channel)
end

local function Receive(text, sender)
  if not (ns.db and ns.db.versions) then return end
  if not (Readable(text) and Readable(sender)) or type(text) ~= "string" then return end
  local list = text:sub(1, #TAG) == TAG and text:sub(#TAG + 1)
  if not list then return end
  local from = sender:match("^[^-]+") or sender
  if from == UnitName("player") then return end
  local mine, changed = Mine(), false
  ns.db.told = ns.db.told or {}
  for name, version in list:gmatch("([%w_]+)=([%w%.]+)") do
    local a = mine[name]
    local s = seen[name]
    if a and IsNewer(version, a.version) and not (s and not IsNewer(version, s.version)) then
      seen[name] = { version = version, from = from }
      changed = true
      if ns.db.told[name] ~= version then
        ns.db.told[name] = version
        ns.Print(("%s %s is out (you have %s; %s has it). Update with CurseForge or Wago.")
          :format(a.title, version, a.version, from))
      end
    end
  end
  if changed and ns.Refill then ns.Refill() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
  if event == "CHAT_MSG_ADDON" then
    if prefix == PREFIX then Receive(text, sender) end
  elseif event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    C_Timer.After(LOGIN_DELAY, function()
      if IsInGuild() then Send("GUILD") end
      SendGroup()
    end)
  else
    SendGroup()
  end
end)
