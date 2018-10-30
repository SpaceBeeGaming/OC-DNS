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
local regEx_string =
  "\b(?:(?:2(?:[0-4][0-9]|5[0-5])|[0-1]?[0-9]?[0-9])%.){3}(?:(?:2([0-4][0-9]|5[0-5])|[0-1]?[0-9]?[0-9]))\b"

--FUNCTIONS
local internal = {}
internal.common = {}

local eventHandler = {}
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
  if (string.match(data, regEx_string)) then
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

function myEventHandlers.REVERSELOOKUP(requester)
  --TODO
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
