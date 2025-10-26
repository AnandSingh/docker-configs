# Cloudflare Dynamic DNS IP Updater

This script is used to update Dynamic DNS (DDNS) service based on Cloudflare! Access your home network remotely via a custom domain name without a static IP! Written in pure BASH.

## Usage
This script is used with crontab. Specify the frequency of execution through crontab.

```bash
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of the month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday 7 is also Sunday on some systems)
# │ │ │ │ │ ┌───────────── command to issue                               
# │ │ │ │ │ │
# │ │ │ │ │ │
# * * * * * /bin/bash {Location of the script}
```

For example running the script every 1 min
Run 
```
crountab -e
```
and add the below line to the file 
```
*/1 * * * * /bin/bash -l -c  '/root/cloudflare-ddns-updater/cloudflare-ddns-updater.sh'
```

restart the cron service
```
systemctl restart cron`

```
Checking the logs of the cron scripts 
```
tail -f /var/log/syslog | grep "DDNS Updater"
```