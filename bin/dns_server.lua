--REQUIRES
local component = require("component")
local modem = component.modem
local ttf = require("tableToFile")
local event = require("event")

local settingsLocation = "/dns/data/DNS_SETTINGS.cfg"
local settings = ttf.load(settingsLocation)
local hosts = ttf.load(settings.HOST_FILE)

settings.lAddr = modem.address
ttf.save(settings, settingsLocation)

local requests = {"DISCOVER", "REGISTER", "LOOKUP", "RLOOKUP"}

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

local dns_event =
  setmetatable(
  {},
  {
    __index = function()
      return unknownEvent
    end
  }
)

function dns_event.DISCOVER(requester)
  modem.send(requester.rAddr, requester.port, "DNS", "DISCOVER", settings.lAddr)
  internal.common.logWrite("DNS | DISCOVER | " .. requester.rAddr:sub(1, 8))
end

function dns_event.REGISTER(requester, ip)
  if (checkIp(ip)) then
    if (hosts[ip] == nil) then
      hosts[ip] = requester.rAddr
      ttf.save(hosts, settings.HOST_FILE)
      modem.send(requester.rAddr, requester.port, "DNS", "REGISTER", true)
      internal.common.logWrite("DNS | REGISTER | " .. requester.rAddr:sub(1, 8) .. " | " .. ip)
    else
      modem.send(requester.rAddr, requester.port, "DNS", "REGISTER", false, "IN_USE")
      internal.common.logWrite("DNS | REGISTER | " .. requester.rAddr:sub(1, 8) .. " | failed: IN_USE")
    end
  else
    modem.send(requester.rAddr, requester.port, "DNS", "REGISTER", false, "INVALID_PATTERN")
    internal.common.logWrite("DNS | REGISTER | " .. requester.rAddr:sub(1, 8) .. " | failed: INVALID_PATTERN")
  end
end

function dns_event.LOOKUP(requester, ip)
  local addr = hosts[ip]
  if addr then
    modem.send(requester.rAddr, requester.port, "DNS", "LOOKUP", addr)
    internal.common.logWrite("DNS | LOOKUP | " .. requester.rAddr:sub(1, 8) .. " | " .. addr:sub(1, 8))
  else
    modem.send(requester.rAddr, requester.port, "DNS", "LOOKUP", false, "NOT_FOUND")
    internal.common.logWrite("DNS | LOOKUP | " .. requester.rAddr:sub(1, 8) .. " | failed: NOT_FOUND")
  end
end

function dns_event.RLOOKUP(requester, addr)
  for k, v in pairs(hosts) do
    if (v == addr) then
      modem.send(requester.rAddr, requester.port, "DNS", "RLOOKUP", k)
      internal.common.logWrite("DNS | RLOOKUP | " .. requester.rAddr:sub(1, 8) .. " | " .. k)

      return
    end
  end
  modem.send(requester.rAddr, requester.port, "DNS", "RLOOKUP", false, "NOT_FOUND")
  internal.common.logWrite("DNS | RLOOKUP | " .. requester.rAddr:sub(1, 8) .. " | failed: NOT_FOUND")
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
  dns_event[type](requester, data)
end

function internal.common.logWrite(text, screen)
  screen = screen or false
  local logFile = io.open(settings.LOG_FILE, "a")
  if (screen) then
    print(text)
  end
  if (logFile) then
    logFile:write(os.date() .. " | " .. text .. "\n")
    logFile:close()
  end
end

function start()
  if (modem.isOpen(settings.port)) then
    print("Port: '" .. settings.port .. "' already in use.")
  else
    modem.open(settings.port)
    event.listen("modem_message", eventHandler.processEvent)
    internal.common.logWrite("DNS | START | port: " .. settings.port, true)
  end
end

function stop()
  ttf.save(settings, settingsLocation)
  event.ignore("modem_message", eventHandler.processEvent)
  modem.close(settings.port)
  internal.common.logWrite("DNS | STOP | port: " .. settings.port, true)
end

--Shutup luacheck.
local debug = false
if debug then
  start()
  stop()
end
