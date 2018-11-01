local component = require("component")
local modem = component.modem
local event = require("event")
local ttf = require("tableToFile")

local settingsLocation = "/usr/data/settings.cfg"
local settings = ttf.load(settingsLocation)

--modem.open(settings.port)
--modem.broadcast(settings.port, "DNS", "DISCOVER")

--local requests = {"DISCOVER"}
local internal = {}

function internal.tableReply(_, rAddr, port, _, service, request, response, reason)
  local reply = {
    rAddr = rAddr,
    port = port,
    service = service,
    request = request,
    response = {
      value = response,
      reason = reason or nil
    }
  }
  return reply
end

function internal.checkDetails(details, reply)
  if (details[1] == reply.service and details[2] == reply.request) then
    return true
  else
    return false
  end
end

function internal.bcSend(details, data)
  modem.broadcast(settings.port, details[1], details[2], data)
end

