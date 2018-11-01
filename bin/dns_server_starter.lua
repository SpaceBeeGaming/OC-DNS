local os = require("os")

os.execute("ln /programs/bin/dns_server.lua /etc/rc.d/dns.lua")
os.execute("ln /programs/bin /usr/bin")
os.execute("ln /programs/lib /usr/lib")
os.setenv("HOSTNAME", "DNS-01")
os.execute("rc")
