local component = require("component")
local modem = component.modem
local event = require("event")
local ttf = require("tableToFile")

local settingsLocation = "/dns/data/DNS_SETTINGS.cfg"
local settings = ttf.load(settingsLocation)

local internal = {}

function internal.tableReply(rAddr, port, service, request, response, reason)
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

local dns_client = {}

function dns_client.discover()
  local details = {"DNS", "DISCOVER"}
  modem.broadcast(settings.port, details[1], details[2])
  local _, _, rAddr, port, _, service, request, value, reason = event.pull(1, "modem_message")
  local reply

  if (rAddr) then
    reply = internal.tableReply(rAddr, port, service, request, value, reason)
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
    modem.send(dns_client.discover(), settings.port, details[1], details[2], data)
  end
end

function internal.request(details, data)
  internal.send(details, data)
  local _, _, rAddr, port, _, service, request, value, reason = event.pull(1, "modem_message")
  local reply
  if (rAddr) then
    reply = internal.tableReply(rAddr, port, service, request, value, reason)
    if (internal.checkDetails(details, reply)) then
      return reply.response.value, reply.response.reason
    end
  else
    return false, "TIMED_OUT"
  end
end

function dns_client.register(ip)
  local details = {"DNS", "REGISTER"}
  return internal.request(details, ip)
end

function dns_client.lookup(ip)
  local details = {"DNS", "LOOKUP"}
  return internal.request(details, ip)
end

function dns_client.rlookup(addr)
  local details = {"DNS", "RLOOKUP"}
  return internal.request(details, addr)
end

function dns_client.start()
  if (modem.open(settings.port)) then
    return true
  else
    return false, "IN_USE"
  end
end

function dns_client.stop()
  modem.close(settings.port)
  return true
end

return dns_client
