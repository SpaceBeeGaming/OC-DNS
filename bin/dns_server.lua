--REQUIRES
local component = require("component")
local modem = component.modem
local ttf = require("tableToFile")
local event = require("event")

local settingsLocation = "/programs/data/DNS_SETTINGS.cfg"
local settings = ttf.load(settingsLocation)

settings.lAddr = modem.address

local requests = {"DISCOVER"}

--FUNCTIONS
local internal = {}
internal.common = {}
internal.dns = {}

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
  modem.send(requester.rAddr, requester.port, settings.lAddr)
  internal.logWrite("DNS | DISCOVER | " .. requester.rAddr:sub(1, 8))
end

function eventHandler.tableEvent(_, _, rAddr, port, _, service, request)
  --//print("event")
  local e = {
    requester = {
      rAddr = rAddr,
      port = port
    },
    header = {
      service = service,
      type = request
    }
  }
  --//print(e.header.service)
  --//print(e.header.type)
  return e
end

function eventHandler.checkRequest(...)
  local e = eventHandler.tableEvent(...)
  if (e.header.service == "DNS") then
    for i = 1, #requests do
      if (e.header.type == requests[i]) then
        --//print("test")
        return e.header.type, e.requester
      end
    end
  end
end

function eventHandler.processEvent(...)
  --//print(...)
  local type, requester = eventHandler.checkRequest(...)
  --//print(type)
  myEventHandlers[type](requester)
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
