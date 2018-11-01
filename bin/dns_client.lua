local component = require("component")
local modem = component.modem
local event = require("event")
local ttf = require("tableToFile")

local settingsLocation = "/usr/data/settings.cfg"
local settings = ttf.load(settingsLocation)

modem.open(settings.port)
modem.broadcast(settings.port, "DNS", "DISCOVER")
local pReply = event.pull(1, "modem_message") --_, rAddr, port, _, service, request, response

local requests = {"DISCOVER"}
local reply = {
  rAddr = pReply[2],
  port = pReply[3],
  service = pReply[5],
  request = pReply[6],
  response = {
    value = pReply[7],
    reason = pReply[8]
  }
}
