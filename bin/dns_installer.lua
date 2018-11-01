local serialization = require("serialization")
local dlURL = "https://raw.githubusercontent.com/SpaceBeeGaming/OC-DNS/master/"

local files = {
  server = {"bin/dns_server.lua", "bin/dns_server_starter.lua", "lib/tableToFile.lua"},
  client = {"bin/dns_client.lua", "lib/tableToFile.lua"}
}

print("Choose what to install.")
print("[1] Server")
print("[2] Client")
local input = io.read()

local port
local settings = {}
if (tostring(input) == "1") then
  files = files.server
  settings.LOG_FILE = "/dns/DNS_LOG.log"
  settings.HOST_FILE = "/dns/HOSTS.log"

  print("Port for DNS communication (default:'9999')")
  port = io.read()
  if port == "" then
    port = nil
  end
  settings.port = tonumber(port) or 9999
elseif (tostring(input) == "2") then
  files = files.client

  print("Port for DNS communication (default:'9999')")
  port = io.read()
  if port == "" then
    port = nil
  end
  settings.port = tonumber(port) or 9999
else
  return
end

local settingsFile = io.open("/dns/DNS_SETTINGS.cfg", "w")
settingsFile:write(serialization.serialize(settings))
settingsFile:close()

for i = 1, #files do
  os.execute("wget " .. dlURL .. i .. " /dns/" .. i)
end
