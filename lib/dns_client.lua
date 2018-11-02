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

local dns = {}

function dns.discover()
  --TEST
  local details = {"DNS", "DISCOVER"}
  modem.broadcast(settings.port, details[1], details[2])
  local pReply = event.pull(1, "modem_message") --_, rAddr, port, _, service, request, response:value, response:reason
  local reply
  if (pReply) then
    reply = internal.tableReply(table.unpack(pReply))
    if (internal.checkDetails(details, reply)) then
      if (reply.response.value) then
        settings.DNS_SERVER = reply.response.value
        ttf.save(settings, settingsLocation)
        return reply.response.value
      end
    else
      return reply.response.value, reply.response.reason
    end
  else
    return false, "TIMED_OUT"
  end
end

function internal.send(details, data)
  if (settings.DNS_SERVER) then
    modem.send(settings.DNS_SERVER, settings.port, details[1], details[2], data)
  else
    dns.discover()
  end
end

function internal.request(details, data)
  --TEST
  internal.send(details, data)
  local pReply = event.pull(1, "modem_message")
  local reply
  if (pReply) then
    reply = internal.tableReply(table.unpack(pReply))
    if (internal.checkDetails(details, reply)) then
      return reply.response.value, reply.response.reason
    end
  else
    return false, "TIMED_OUT"
  end
end

function dns.register(ip)
  --TEST
  local details = {"DNS", "REGISTER"}
  return internal.request(details, ip)
end

function dns.lookup(ip)
  --TEST
  local details = {"DNS", "LOOKUP"}
  return internal.request(details, ip)
end

function dns.rlookup(addr)
  --TEST
  local details = {"DNS", "RLOOKUP"}
  return internal.request(details, addr)
end

function dns.start()
  if (modem.open(settings.port)) then
    return true
  else
    return false, "IN_USE"
  end
end

function dns.stop()
  modem.close(settings.port)
end

return dns
