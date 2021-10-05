#!/bin/sh

while true; do
  reload_dns=false
  if [ -r /etc/dhcpd/dhcpd-leases.log ]; then
    LOGATIME=`stat /etc/dhcpd/dhcpd-leases.log | grep Modify`
    if [ "$LOGATIME" != "$LOGLASTATIME" ]; then
      date
      LOGLASTATIME=$LOGATIME
      reload_dns=true
    fi
  elif [ -r /etc/dhcpd/dhcpd.conf.leases ]; then
    LEASEATIME=`stat /etc/dhcpd/dhcpd.conf.leases | grep Modify`
    if [ "$LEASEATIME" != "$LEASELASTATIME" ]; then
      date
      LEASELASTATIME=$LEASEATIME
      reload_dns=true
    fi
  else
    echo "ERROR - No dhcp lease files found.  Is something misconfigured?"
    exit 1
  fi
  if "$reload_dns"; then
    echo "dhcp leases changed - reloading DNS"
    $(dirname $0)/diskstation_dns_modify.sh
  fi
  sleep 5
done


