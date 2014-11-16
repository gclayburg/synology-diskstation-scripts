#!/bin/ash
YourNetworkName=home.lan
ForwardMasterFile=home.lan
ReverseMasterFile=1.168.192.in-addr.arpa
#todo automagically determine filenames for forward and reverse zones, so that this file does not need to be edited
# to work in a default config

#If you define StaticIpStart and StaticIpEnd, then and static IP addresses defined in DNS will be preserved
#If StaticIpStart and StaticIpEnd is not defined, then all IP addresses are assumed to be originating from DHCP assignment
#Here we assume DHCP is configured to assign address starting at 192.168.1.100
StaticIpStart=1
StaticIpEnd=99


# Note that backup path is also used as a temp folder.
BackupPath=/var/services/homes/admin/scripts/dns_backups
ZoneRootDir=/var/packages/DNSServer/target
ZonePath=$ZoneRootDir/named/etc/zone/master
DHCPAssigned=/etc/dhcpd/dhcpd.conf

# An address may not have been assigned yet so verify
# the leases log file exists before assigning.
DHCPLeases=/etc/dhcpd/dhcpd-leases.log
[ -f $DHCPLeases ] && DHCPAssigned="$DHCPAssigned $DHCPLeases"

DHCPStatic=/etc/dhcpd/dhcpd-static-static.conf
# this file may not exist if you haven't configured anything in the dhcp static reservations list (mac addr -> ip addr)
[ -f $DHCPStatic ] && DHCPAssigned="$DHCPAssigned $DHCPStatic"

##########################################################################
# Verify files exist and appropriate rights are granted
# Fail if environment is not set up correctly.
#TODO

##########################################################################
# Back up the forward and reverse master files
# Two options: a) One backup which is overwritten each time 
# or b) file is backed up once each day... but only the first use and
# retained for one year.
#
if ! mkdir -p ${BackupPath}; then
  echo "Error: cannot create backup directory"
  exit 3
fi

tmpPrefix=$BackupPath/DNS_Backup_$(date +%m%d)
echo "Backing up DNS files to $tmpPrefix.*"
[ -f $tmpPrefix.$ForwardMasterFile ] && echo "INFO: Forward master already backed up for today." || cp -a $ZonePath/$ForwardMasterFile $tmpPrefix.$ForwardMasterFile
[ -f $tmpPrefix.$ReverseMasterFile ] && echo "INFO: Reverse master already backed up for today." || cp -a $ZonePath/$ReverseMasterFile $tmpPrefix.$ReverseMasterFile

# Declare reusable functions.  Logic is pretty much the same for forward and reverse files.
printPartialDNSFile () {
   # Pass in the DNS file to process (forward or reverse master)
   # Print everything except for PTR and A records.
   # The only exception are "ns.domain" records.  We keep those.
   #Assumptions:
   # PTR and A records should be removed unless they contain "ns.<YourNetworkName>."
   awk -v YourNetworkName=$YourNetworkName -v staticipstart=$StaticIpStart -v staticipend=$StaticIpEnd '
      BEGIN {
        nsrecord="ns."
        YourNetworkName ".";
      }
      {
        if( $3 == "A"){
          IP=$4;
          split(IP,iparr,".");
          if (iparr[4] >= staticipstart && iparr[4] <= staticipend) {
            # class C addresses between 1 and 109 are considered static IP addresses
            # todo: parse the start and end boundaries from the DHCP config files
            # instead of requiring manual input here
            PrintThis=1;
            # print records that are intended to be static IP addresses, i.e. they are not assigned by DHCP
          } else{
            PrintThis=0; # By default, do not print PTR or A records.
          }
        } else if($3 == "PTR" ){
          REVERSEIP=$1;
          split(REVERSEIP,iparr,".");
          if (iparr[1] >= staticipstart && iparr[1] <= staticipend) {
            # class C addresses between 1 and 109 are considered static IP addresses
            # todo: parse the start and end boundaries from the DHCP config files
            # instead of requiring manual input here
            PrintThis=1;
            # print records that are intended to be static IP addresses, i.e. they are not assigned by DHCP
          } else{
            PrintThis=0; # By default, do not print PTR or A records.
          }
        } else
          PrintThis=1;
       }
      (($1 == nsrecord ) || ( $4 == nsrecord )) {PrintThis = 1} # Unless they talk about ns records.
      (PrintThis == 1) {print $0 }
   ' $1
}

printDhcpAsRecords () {
	# Pass in "A" for A records and "PTR" for PTR records.
	# Process the DHCP static and dynamic records
	# Logic is the same for PTR and A records.  Just a different print output.
	# Sorts and remove duplicates. Filters records you don't want.
	awk -v YourNetworkName=$YourNetworkName -v RecordType=$1 '
		BEGIN {
		   # Set awks field separator and network adapter names.
		   FS="[\t =,]";
		   adapters=",eth0,eth1,eth2,eth3,eth4,eth5,eth6,eth7,bond0,bond1,bond2,bond3,,";
		}
		{IP=""} # clear out variables
		$1 ~ /^[0-9]/ {IP=$3; NAME=$4; RENEW=86400} # Leases start with numbers
		$1 == "dhcp-host" {IP=$4; NAME=$3; RENEW=$5} # Static assignments start with dhcp-host
		index(adapters, "," NAME "," ) > 0 {IP="";} # Dont print if machine name is a network adapter
		(IP != "") {
		   split(IP,arr,".");
		   ReverseIP = arr[4] "." arr[3] "." arr[2] "." arr[1];
		   # Print the last number in the IP address so we can sort the addresses
		   # Add a tab character so that "cut" sees two fields... it will print the second
		   # field and remove the first which is the last number in the IP address.
		   if (RecordType == "PTR") {print 1000 + arr[4] "\t" ReverseIP ".in-addr.arpa. " RENEW " PTR " NAME "." YourNetworkName "."}
		   if (RecordType == "A") print 2000 + arr[4] "\t" NAME "." YourNetworkName ". " RENEW " A " IP
		}
	' $DHCPAssigned | sort | cut -f2 - | uniq
}
##########################################################################
# FORWARD MASTER FILE FIRST - (Logic is the same for both)
# Print everything except for PTR and A records.
# The only exception are "ns.domain" records.  We keep those.
#Assumptions:
# PTR and A records should be removed unless they contain "ns.<YourNetworkName>."
echo "Regenerating forward master file $ForwardMasterFile"

printPartialDNSFile $ZonePath/$ForwardMasterFile  > $BackupPath/$ForwardMasterFile.new
printDhcpAsRecords "A" >> $BackupPath/$ForwardMasterFile.new


##########################################################################
# REVERSE MASTER FILE - (Logic is the same for both)
# Print everything except for PTR and A records.
# The only exception are "ns.domain" records.  We keep those.
#Assumptions:
# PTR and A records should be removed unless they contain "ns.<YourNetworkName>."
echo "Regenerating reverse master file $ReverseMasterFile"

printPartialDNSFile $ZonePath/$ReverseMasterFile  > $BackupPath/$ReverseMasterFile.new
printDhcpAsRecords "PTR" >> $BackupPath/$ReverseMasterFile.new


##########################################################################
# Ensure the owner/group and modes are set at default
# then overwrite the original files
echo "Overwriting with updated files: $ForwardMasterFile $ReverseMasterFile"
if ! chown nobody:nobody $BackupPath/$ForwardMasterFile.new $BackupPath/$ReverseMasterFile.new ; then
  echo "Error:  Cannot change file ownership"
  echo ""
  echo "Try running this script as root for correct permissions"
  exit 4
fi
chmod 644 $BackupPath/$ForwardMasterFile.new $BackupPath/$ReverseMasterFile.new
#cp -a $BackupPath/$ForwardMasterFile.new $ZonePath/$ForwardMasterFile 
#cp -a $BackupPath/$ReverseMasterFile.new $ZonePath/$ReverseMasterFile 

mv -f $BackupPath/$ForwardMasterFile.new $ZonePath/$ForwardMasterFile
mv -f $BackupPath/$ReverseMasterFile.new $ZonePath/$ReverseMasterFile

##########################################################################
# Reload the server config after modifications
$ZoneRootDir/script/reload.sh

exit 0
