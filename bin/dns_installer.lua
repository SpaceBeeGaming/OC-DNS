local serialization = require("serialization")
local fs = require("filesystem")
local dlURL = "https://raw.githubusercontent.com/SpaceBeeGaming/OC-DNS/master/"

local files = {
  server = {"bin/dns_server.lua", "bin/dns_server_starter.lua", "lib/tableToFile.lua"},
  client = {"lib/dns_client.lua", "lib/tableToFile.lua"}
}

local update = fs.exists("/dns")
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
  fs.makeDirectory("/dns/data")
  files = files.server
  settings.LOG_FILE = "/dns/DNS_LOG.log"
  settings.HOST_FILE = "/dns/data/HOSTS.txt"

  io.write("Port for DNS communication (default:'9999'): ")
  port = io.read()
  if port == "" then
    port = nil
  end
  settings.port = tonumber(port) or 9999
  io.write("Enforce 'ipv4' addresses? [Y/n]: ")
  if (io.read():lower() == "y") then
    settings.formalAddr = true
  else
    settings.formalAddr = false
  end
elseif (tostring(input) == "2") then
  files = files.client
  fs.makeDirectory("/dns/lib")
  fs.makeDirectory("/dns/data")

  io.write("Port for DNS communication (default:'9999'): ")
  port = io.read()
  if port == "" then
    port = nil
  end
  settings.port = tonumber(port) or 9999
else
  print("'" .. input .. "' is not '1' or '2'")
end

--fs.makeDirectory("/dns")
if not update then
  local settingsFile = io.open("/dns/data/DNS_SETTINGS.cfg", "w")
  settingsFile:write(serialization.serialize(settings))
  settingsFile:close()
end

for i = 1, #files do
  os.execute("wget -f " .. dlURL .. files[i] .. " /dns/" .. files[i])
end
if (tostring(input) == "1") then
  if not update then
    local hostFile = io.open("/dns/data/HOSTS.txt", "a")
    hostFile:write("{}")
    hostFile:close()

    local shellFile = io.open(os.getenv("HOME") .. "/.shrc", "a")
    shellFile:write("/dns/bin/dns_server_starter.lua\n")
    shellFile:close()
  end

  io.write("Installation finished. Do you want to start the server: [Y/n]: ")
  if (io.read():lower() == "n") then
    return
  else
    os.execute("/dns/bin/dns_server_starter.lua")
    os.execute("rc dns enable")
    os.execute("rc dns start")
  end
else
  local shellFile = io.open(os.getenv("HOME") .. "/.shrc", "a")
  shellFile:write("ln /dns/lib /usr/lib\n")
  shellFile:close()
  os.execute("ln /dns/lib /usr/lib")
  print("Installation finished.")
end
