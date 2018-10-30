--REQUIRES
local component = require("component")
local modem = component.modem
local ttf = require("tableToFile")
local event = require("event")

local settingsLocation = "/programs/data/DNS_SETTINGS.cfg"
local settings = ttf.load(settingsLocation)
local hosts = ttf.load(settings.HOST_FILE)

settings.lAddr = modem.address

local requests = {"DISCOVER", "REGISTER", "LOOKUP", "REVERSELOOKUP"}

local eventHandler = {}
local internal = {}
internal.common = {}
--FUNCTIONS

local function checkIp(ip)
  --Source: https://luacode.wordpress.com/2012/01/09/checking-ip-address-format-in-lua/
  if not ip then
    return false
  end
  local a, b, c, d = ip:match("^(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)$")
  a = tonumber(a)
  b = tonumber(b)
  c = tonumber(c)
  d = tonumber(d)
  if (a == nil or b == nil or c == nil or d == nil) then
    return false
  end
  if (a < 0 or a > 255) then
    return false
  end
  if (b < 0 or b > 255) then
    return false
  end
  if (c < 0 or c > 255) then
    return false
  end
  if (d < 0 or d > 255) then
    return false
  end
  return true
end

local function unknownEvent()
end
local myEventHandlers =
  setmetatable(
  {},
  {
    __index = function()
      return unknownEvent
    end
  }
)

function myEventHandlers.DISCOVER(requester)
  --TEST
  modem.send(requester.rAddr, requester.port, "DNS", "DISCOVER", settings.lAddr)
  internal.common.logWrite("DNS | DISCOVER | " .. requester.rAddr:sub(1, 8))
end

function myEventHandlers.REGISTER(requester, data)
  --TEST
  if (checkIp(data)) then
    if (hosts[data] == nil) then
      hosts[data] = requester.rAddr
      ttf.save(hosts, settings.HOST_FILE)
      modem.send(requester.rAddr, requester.port, "DNS", "REGISTER", true)
      internal.common.logWrite("DNS | REGISTER | " .. requester.rAddr:sub(1, 8) .. " | " .. data)
    else
      modem.send(requester.rAddr, requester.port, "DNS", "REGISTER", false, "IN_USE")
      internal.common.logWrite("DNS | REGISTER | " .. requester.rAddr:sub(1, 8) .. " | failed: IN_USE")
    end
  else
    modem.send(requester.rAddr, requester.port, "DNS", "REGISTER", false, "INVALID_PATTERN")
    internal.common.logWrite("DNS | REGISTER | " .. requester.rAddr:sub(1, 8) .. " | failed: INVALID_PATTERN")
  end
end

function myEventHandlers.LOOKUP(requester)
  --TODO
end

function myEventHandlers.REVERSELOOKUP(requester, addr)
  --TEST
  for k, v in pairs(hosts) do
    if (v == addr) then
      modem.send(requester.rAddr, requester.port, "DNS", "REVERSELOOKUP", k)
      internal.common.logWrite("DNS | LOOKUP | " .. requester.rAddr:sub(1, 8) .. " | " .. k)
      break
    end
  end
  modem.send(requester.rAddr, requester.port, "DNS", "REVERSELOOKUP", false, "NOT_FOUND")
  internal.common.logWrite("DNS | LOOKUP | " .. requester.rAddr:sub(1, 8) .. " | failed: NOT_FOUND")
end

function eventHandler.tableEvent(_, _, rAddr, port, _, service, request, data)
  local e = {
    requester = {
      rAddr = rAddr,
      port = port
    },
    header = {
      service = service,
      type = request
    },
    data = data or nil
  }
  return e
end

function eventHandler.checkRequest(...)
  local e = eventHandler.tableEvent(...)
  if (e.header.service == "DNS") then
    for i = 1, #requests do
      if (e.header.type == requests[i]) then
        --//print("test")
        return e.header.type, e.requester, e.data
      end
    end
  end
end

function eventHandler.processEvent(...)
  local type, requester, data = eventHandler.checkRequest(...)
  myEventHandlers[type](requester, data)
end

function internal.common.logWrite(text, screen)
  screen = screen or false
  local logFile = io.open(settings.LOG_FILE, "a")
  if (screen) then
    print(text)
  end
  if (logFile) then
    logFile:write(os.date() .. " | " .. text .. "\n")
  end
end

local dns = {}

function dns.start()
  if (modem.isOpen(settings.port)) then
    print("Port: '" .. settings.port .. "' already in use.")
  else
    modem.open(settings.port)
    event.listen("modem_message", eventHandler.processEvent)
    internal.common.logWrite("Started DNS on port: " .. settings.port, true)
  end
end

function dns.stop()
  ttf.save(settings, settingsLocation)
  event.ignore("modem_message", eventHandler.processEvent)
  modem.close(settings.port)
  internal.common.logWrite("Stopped DNS on port: " .. settings.port, true)
end

--TODO: Remove
dns.start()
dns.stop()
return dns
