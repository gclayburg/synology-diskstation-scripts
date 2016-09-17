#!/bin/sh
#nohup ./poll-dhcp-changes.sh >> /volume1/homes/admin/logs/dhcp-dns.log 2>&1 &
#nohup does not work on synology.  As a workaround, this script should be started from
# DSM task scheduler.
date
echo "is poll-dhcp-changes.sh running?"
POLL_RUNNING=`ps x | grep poll-dhcp-changes | grep -v grep |wc -l`
if [ $POLL_RUNNING -gt "0" ]; then
  echo "poll-dhcp-changes already running."
else
  echo "starting poll-dhcp-changes"
  /volume1/homes/admin/poll-dhcp-changes.sh >> /volume1/homes/admin/logs/dhcp-dns.log 2>&1 
fi
