#!/bin/sh

while true; do    
   ATIME=`stat /etc/dhcpd/dhcpd.conf.leases g | grep Modify`
   
   if [[ "$ATIME" != "$LTIME" ]]; then
     date
     echo "dhcp leases changed - reloading DNS"
     /var/services/homes/admin/diskstation_dns_modify.sh
     LTIME=$ATIME
   fi
   sleep 5
done