-- Which Meio addon broke: a Lua error or blocked action whose file path (or "AddOn 'Name'")
-- names one of ours gets one chat line per addon per session, with where to report it, and
-- a mark on its row. Read from MeioErrors, else BugGrabber (it owns the error handler);
-- with neither, the handler is wrapped and Blizzard's own goes on as before.
-- Off: /meiohub errors off.
local ADDON, ns = ...

local AUTHOR, CATEGORY = "MeioNeiz", "Meio"
local MAX_SHOWN = 140

local errors = {} -- addon name -> { count, message }

-- metadata of a name that isn't an addon can throw
local function Meta(name, key)
  local ok, v = pcall(C_AddOns.GetAddOnMetadata, name, key)
  return ok and v or nil
end

local function Ours(name)
  if not name then return false end
  return name == ADDON or Meta(name, "Author") == AUTHOR
    or Meta(name, "Category") == CATEGORY
end

local function FromPath(text)
  for name in text:gmatch("AddOns[/\\]([%w_]+)[/\\]") do
    if Ours(name) then return name end
  end
end

-- the file the error is in first, else a blocked action's addon, else the first Meio frame
-- on the stack (our hook called the code that failed)
local function Culprit(message, stack)
  local blocked = message:match("AddOn '([%w_]+)'")
  return FromPath(message) or (Ours(blocked) and blocked) or (stack and FromPath(stack))
end

local function Short(message)
  local s = message:gsub("^[^\n]*AddOns[/\\][%w_]+[/\\]", ""):match("^[^\n]*")
  if #s > MAX_SHOWN then s = s:sub(1, MAX_SHOWN - 3) .. "..." end
  return s
end

function ns.IssuesLink(name)
  local site = Meta(name, "X-Website")
  if site and site:find("github%.com/") then
    return (site:gsub("^https?://", ""):gsub("/$", "")) .. "/issues"
  end
end

local function Record(message, stack, times)
  if not (ns.db and ns.db.errors) or type(message) ~= "string" then return end
  if issecretvalue and issecretvalue(message) then return end
  local name = Culprit(message, type(stack) == "string" and stack or nil)
  if not name then return end
  local e = errors[name]
  times = times or 1
  if e then
    e.count = e.count + times
  else
    e = { count = times, message = Short(message) }
    errors[name] = e
    local title = Meta(name, "Title") or name
    local link = ns.IssuesLink(name)
    ns.Print(("%s hit a Lua error: %s%s"):format(title, e.message,
      link and (". Please report it at " .. link) or ""))
  end
  if ns.Refill then ns.Refill() end
end

function ns.Errors(a)
  return a and errors[a.name]
end

-- BugGrabber keeps one object per distinct error and counts repeats on it
local counted = {} -- error object -> its counter when last read
local function ReadBug(err)
  if type(err) ~= "table" then return end
  local n = tonumber(err.counter) or 1
  local new = n - (counted[err] or 0)
  counted[err] = n
  if new > 0 then Record(err.message, err.stack, new) end
end

-- an error of ours in here would come straight back to us through BugGrabber: swallowed
local function FromBugGrabber(_, id)
  local bg = _G.BugGrabber
  pcall(ReadBug, bg and bg.GetErrorByID and bg:GetErrorByID(id))
end

-- this session's errors from before MeioHub loaded (addons earlier in the list)
local function ScanBugGrabber()
  local bg = _G.BugGrabber
  if not (bg and bg.GetDB and bg.GetSessionId) then return end
  local session = bg:GetSessionId()
  for _, err in ipairs(bg:GetDB() or {}) do
    if type(err) == "table" and err.session == session then ReadBug(err) end
  end
end

local function WrapHandler()
  local prev = geterrorhandler()
  seterrorhandler(function(message, ...)
    pcall(Record, message, debugstack and debugstack(3))
    return prev(message, ...)
  end)
  local f = CreateFrame("Frame")
  f:RegisterEvent("ADDON_ACTION_BLOCKED")
  f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
  f:SetScript("OnEvent", function(_, event, name, fn)
    Record(("[%s] AddOn '%s' tried to call the protected function '%s'."):format(event,
      tostring(name), tostring(fn)))
  end)
end

-- MeioErrors counts repeats on one entry per message, per session in sessionCounter
local read = {} -- entry -> its sessionCounter when last read
local function ReadMeio(e)
  if type(e) ~= "table" or e.session ~= MeioErrors.GetSession() then return end
  local n = tonumber(e.sessionCounter) or 1
  local new = n - (read[e] or 0)
  read[e] = n
  if new > 0 then Record(e.message, e.stack, new) end
end

local function ScanMeioErrors()
  for _, e in ipairs(MeioErrors.GetErrors() or {}) do ReadMeio(e) end
end

-- MeioErrors first: it loads before us and also reads BugGrabber when that keeps the handler
local usingMeioErrors = type(_G.MeioErrors) == "table" and MeioErrors.Listen and true
local usingBugGrabber = not usingMeioErrors and _G.BugGrabber and EventRegistry and true
if usingMeioErrors then
  MeioErrors.Listen(function(e) pcall(ReadMeio, e) end)
elseif usingBugGrabber then
  EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", FromBugGrabber, ns)
else
  WrapHandler()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  local scan = usingMeioErrors and ScanMeioErrors or usingBugGrabber and ScanBugGrabber
  if scan then
    local ok, err = pcall(scan)
    if not ok then geterrorhandler()(err) end
  end
end)
