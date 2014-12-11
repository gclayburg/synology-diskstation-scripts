#!/bin/sh

while true; do    
   ATIME=`stat /etc/dhcpd/dhcpd-leases.log | grep Modify`
   
   if [[ "$ATIME" != "$LTIME" ]]; then
     date
     echo "dhcp leases changed - reloading DNS"
     /volume1/homes/admin/diskstation_dns_modify.sh
     LTIME=$ATIME
   fi
   sleep 5
done


