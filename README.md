# Script for setting up the proxy with sing-box

This script requests your already created domain and mail for ACME with [Let’s Encrypt](https://letsencrypt.org/), then downloads and installs [sing-box](https://github.com/SagerNet/sing-box) on your server. 

The creation of a configuration file for the sing-box and systemd daemon follows. Once all the conditions are met and the configuration is created, the [sing-box](https://github.com/SagerNet/sing-box) daemon starts its work.

## In order to begin, do the following:

Run this command, which download and execute this script:
```bash 
<(curl -s https://raw.githubusercontent.com/reduxvzr/sing-box-script/main/sing-box-script.sh)
```

## After installation:
After executing this command shows the status of the running [sing-box](https://github.com/SagerNet/sing-box) service.

During its execution, the following information is displayed in the console for further connection to this server: 
connection port, proxy protocol, generated password, and uuid and username for those types of connections that need it.
