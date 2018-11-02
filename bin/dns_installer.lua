local serialization = require("serialization")
local fs = require("filesystem")
local dlURL = "https://raw.githubusercontent.com/SpaceBeeGaming/OC-DNS/master/"

local files = {
  server = {"bin/dns_server.lua", "bin/dns_server_starter.lua", "lib/tableToFile.lua"},
  client = {"lib/dns_client.lua", "lib/tableToFile.lua"}
}

print("Choose what to install.")
print("[1] Server")
print("[2] Client")
local input = io.read()

io.write("Are you sure? [Y/n]: ")
if (io.read():lower() == "n") then --TEST: Is this allowed?
  return
end
local port
local settings = {}
if (tostring(input) == "1") then
  fs.makeDirectory("/dns/bin")
  fs.makeDirectory("/dns/lib")
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
  fs.makeDirectory("/dns/lib")

  print("Port for DNS communication (default:'9999')")
  port = io.read()
  if port == "" then
    port = nil
  end
  settings.port = tonumber(port) or 9999
else
  print("'" .. input .. "' is not '1' or '2'")
end

--fs.makeDirectory("/dns")
local settingsFile = io.open("/dns/DNS_SETTINGS.cfg", "w")
settingsFile:write(serialization.serialize(settings))
settingsFile:close()

for i = 1, #files do
  os.execute("wget " .. dlURL .. files[i] .. " /dns/" .. files[i])
end
if (tostring(input) == "1") then
  local shellFile = io.open("$HOME/.shrc", "a")
  shellFile:write("/dns/bin/dns_server_starter.lua\n")
  io.write("Installation finished. Do you want to start the server: [Y/n]: ")
  if (io.read():lower() == "n") then
    return
  else
    os.execute("/dns/bin/dns_server_starter.lua")
    os.execute("rc dns enable")
    os.execute("rc") --? Is this needed?
  end
else
  print("Installation finished.")
end
