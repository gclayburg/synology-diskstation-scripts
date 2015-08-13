#!/bin/sh
# This script should be installed on a synology diskstation in this folder for automatic startup:
# /usr/local/etc/rc.d/
#
# For full functionality, these scripts should also be installed:
# /var/services/homes/admin/poll-dhcp-changes.sh
# /var/services/homes/admin/diskstation_dns_modify.sh
#
# See Readme.md on github  https://github.com/gclayburg/synology-diskstation-scripts


if [ "$1" = "start"  ]; then
#nohup ./poll-dhcp-changes.sh >> /var/services/homes/admin/logs/dhcp-dns.log 2>&1 &
#nohup does not work on synology.
  date
  echo "is poll-dhcp-changes.sh running?"
  POLL_RUNNING=`ps | grep poll-dhcp-changes | grep -v grep |wc -l`
  if [ $POLL_RUNNING -gt "0" ]; then
    echo "poll-dhcp-changes already running."
  else
    echo "starting poll-dhcp-changes"
    mkdir /var/services/homes/admin/logs/
    /var/services/homes/admin/poll-dhcp-changes.sh >> pwd 2>&1 &
  fi

elif [ "$1" = "stop" ]; then
  MYPID=`ps | grep poll-dhcp-changes | grep -v grep | awk -F' ' '{print $1}'`
  if [ "$MYPID" -gt "1" ]; then
    echo "killing PID: $MYPID"
    kill $MYPID
  fi
fi

