#!/bin/ash
# These settings should be edited to match the settings of your existing DNS server configurtion on your synology server (Main Menu -> DNS Server -> Zones)
#YourNetworkName -> Domain name column
#ForwardMasterFile -> Zone ID column
#ReverseMasterFile -> Zone ID column
YourNetworkName=home.lan
ForwardMasterFile=home.lan
ReverseMasterFile=1.168.192.in-addr.arpa

LOG_CONTEXT="-"  #override to add extra stuff to log messages
date_echo(){
    datestamp=$(date +%F_%T)
    echo "${datestamp} ${LOG_CONTEXT} $*"
}

overridesettings(){
  # $1 is both script global variable name and the parameter name in settings file
  settingsfile=$(dirname $0)/settings

  if [ -r $settingsfile ]; then
    if ignoredresult=$(cat $settingsfile | grep $1=); then
      value=$(cat $settingsfile | grep $1= | head -1 | cut -f2 -d"=")
      eval "$1=$value"
      date_echo "[overriding] $1=$value"
    fi
  else
    date_echo "WARNING: no settings file found.  Using default settings for $1"
  fi
}
date_echo " $0 starting..."
# user specific settings are loaded from settings file, if present.  This makes upgrading this script easier.
overridesettings YourNetworkName
overridesettings ForwardMasterFile
overridesettings ReverseMasterFile

#todo automagically determine filenames for forward and reverse zones, so that this file does not need to be edited
# to work in a default config


#Note: the remainder of this script should not need to be modified
# Note that backup path is also used as a temp folder.
BackupPath=/var/services/homes/admin/scripts/dns_backups
ZoneRootDir=/var/packages/DNSServer/target
ZonePath=$ZoneRootDir/named/etc/zone/master
DHCPAssigned=/etc/dhcpd/dhcpd.conf

NetworkInterfaces=",`ip -o link show | awk -F': ' '{printf $2","}'`"

date_echo "Network interfaces:"
date_echo $NetworkInterfaces

# An address may not have been assigned yet so verify
# the leases log file exists before assigning.
DHCPLeases=/etc/dhcpd/dhcpd-leases.log
[ -f $DHCPLeases ] && DHCPAssigned="$DHCPAssigned $DHCPLeases"

DHCPStatic=/etc/dhcpd/dhcpd-static-static.conf
# this file may not exist if you haven't configured anything in the dhcp static reservations list (mac addr -> ip addr)
[ -f $DHCPStatic ] && DHCPAssigned="$DHCPAssigned $DHCPStatic"

DHCPeth0=/etc/dhcpd/dhcpd-eth0-static.conf
#Reportedly, this is the name of the leases file under DSM 6.0.  If it exists, we scan it.
[ -f $DHCPeth0 ] && DHCPAssigned="$DHCPAssigned $DHCPeth0"

DHCPLeaseFile=/etc/dhcpd/dhcpd.conf.leases
[ -f $DHCPLeaseFile ] && DHCPAssigned="$DHCPAssigned $DHCPLeaseFile"

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
  date_echo "Error: cannot create backup directory"
  exit 3
fi

tmpPrefix=$BackupPath/DNS_Backup_$(date +%m%d)
date_echo "Backing up DNS files to $tmpPrefix.*"
[ -f $tmpPrefix.$ForwardMasterFile ] && date_echo "INFO: Forward master already backed up for today." || cp -a $ZonePath/$ForwardMasterFile $tmpPrefix.$ForwardMasterFile
[ -f $tmpPrefix.$ReverseMasterFile ] && date_echo "INFO: Reverse master already backed up for today." || cp -a $ZonePath/$ReverseMasterFile $tmpPrefix.$ReverseMasterFile

# Declare reusable functions.  Logic is pretty much the same for forward and reverse files.
printPartialDNSFile () {
   # Pass in the DNS file to process (forward or reverse master)
   # Print everything except for PTR and A records.
   # The only exception are "ns.domain" records.  We keep those.
   #Assumptions:
   # PTR and A records should be removed unless they contain "ns.<YourNetworkName>."
   awk '
      {
        if (length($0) < 1) { next };
        if (match($0, ";dynamic") != 0) { next };
        print $0;
      }
   ' $1
}

printDhcpAsRecords () {
	# Pass in "A" for A records and "PTR" for PTR records.
	# Process the DHCP static and dynamic records
	# Logic is the same for PTR and A records.  Just a different print output.
	# Sorts and remove duplicates. Filters records you don't want.
    awk -v YourNetworkName=$YourNetworkName -v RecordType=$1  -v StaticRecords=$2 -v adapters=$NetworkInterfaces '
        BEGIN {
           # Set awks field separator
           FS="[\t =,]";
        }
        {IP=""} # clear out variables
        # Leases start with numbers. Do not use if column 4 is an interface
        $1 ~ /^[0-9]/ {  if(NF>4 || index(adapters, "," $4 "," ) == 0) { IP=$3; NAME=$4; RENEW=86400 } }
        # Static assignments start with dhcp-host
        $1 == "dhcp-host" {IP=$4; NAME=$3; RENEW=$5}
        # If we have an IP and a NAME (and if name is not a placeholder)
        (IP != "" && NAME!="*" && NAME!="") {
           split(IP,arr,".");
           ReverseIP = arr[4] "." arr[3] "." arr[2] "." arr[1];
           if(RecordType == "PTR" && index(StaticRecords, ReverseIP ".in-addr.arpa.," ) > 0) {IP="";}
           if(RecordType == "A" && index(StaticRecords, NAME "." YourNetworkName ".," ) > 0) {IP="";}
           # Remove invalid characters according to rfc952
           gsub(/([^a-zA-Z0-9-]*|^[-]*|[-]*$)/,"",NAME)
           # Print the last number in the IP address so we can sort the addresses
           # Add a tab character so that "cut" sees two fields... it will print the second
           # field and remove the first which is the last number in the IP address.
           if(IP != "" && NAME!="*" && NAME!="") {
               if (RecordType == "PTR") {print 1000 + arr[4] "\t" ReverseIP ".in-addr.arpa.\t" RENEW "\tPTR\t" NAME "." YourNetworkName ".\t;dynamic"}
               if (RecordType == "A") print 2000 + arr[4] "\t" NAME "." YourNetworkName ".\t" RENEW "\tA\t" IP "\t;dynamic"
           }
        }
    ' $DHCPAssigned| sort | cut -f 2- | uniq


}

incrementSerial () {
# serial number must be incremented in SOA record when DNS changes are made so that slaves will recognize a change
  ser=$(sed -e '1,/.*SOA/d' $1 | sed -e '2,$d' -e 's/[ \t]*//' -e 's/;.*//' )  #isolate DNS serial from first line following SOA, removing white space
  comments=$(sed -e '1,/.*SOA/d' $1 | sed -e '2,$d' | sed -n '/;/p' |sed -e 's/.*;//' )  #preserve any comments, if any exist
  bumpedserial=$(( $ser +1 ))

  sed -n '1,/.*SOA/p' $1
  echo -e "\t$bumpedserial ;$comments"
  sed -e '1,/.*SOA/d' $1 | sed -n '2,$p'


}
##########################################################################
# FORWARD MASTER FILE FIRST - (Logic is the same for both)
# Print everything except for PTR and A records.
# The only exception are "ns.domain" records.  We keep those.
#Assumptions:
# PTR and A records should be removed unless they contain "ns.<YourNetworkName>."
date_echo "Regenerating forward master file $ForwardMasterFile"
PARTIAL="$(printPartialDNSFile $ZonePath/$ForwardMasterFile)"
date_echo "forward master file static DNS addresses:"
echo "$PARTIAL"
echo
STATIC=$(echo "$PARTIAL"|awk '{if(NF>3 && NF<6) print $1}'| tr '\n' ',')
echo "$PARTIAL"  > $BackupPath/$ForwardMasterFile.new
date_echo "adding these DHCP leases to DNS forward master file:"
printDhcpAsRecords "A" $STATIC
echo
printDhcpAsRecords "A" $STATIC >> $BackupPath/$ForwardMasterFile.new

incrementSerial $BackupPath/$ForwardMasterFile.new > $BackupPath/$ForwardMasterFile.bumped

##########################################################################
# REVERSE MASTER FILE - (Logic is the same for both)
# Print everything except for PTR and A records.
# The only exception are "ns.domain" records.  We keep those.
#Assumptions:
# PTR and A records should be removed unless they contain "ns.<YourNetworkName>."
date_echo "Regenerating reverse master file $ReverseMasterFile"
PARTIAL="$(printPartialDNSFile $ZonePath/$ReverseMasterFile)"
STATIC=$(echo "$PARTIAL"|awk '{if(NF>3 && NF<6) print $1}'| tr '\n' ',')
date_echo "Reverse master file static DNS addresses:"
echo "$PARTIAL"
echo
echo "$PARTIAL" > $BackupPath/$ReverseMasterFile.new
date_echo "adding these DHCP leases to DNS reverse master file: "
printDhcpAsRecords "PTR" $STATIC
echo
printDhcpAsRecords "PTR" $STATIC >> $BackupPath/$ReverseMasterFile.new
incrementSerial $BackupPath/$ReverseMasterFile.new > $BackupPath/$ReverseMasterFile.bumped


##########################################################################
# Ensure the owner/group and modes are set at default
# then overwrite the original files
date_echo "Overwriting with updated files: $ForwardMasterFile $ReverseMasterFile"
if ! chown nobody:nobody $BackupPath/$ForwardMasterFile.bumped $BackupPath/$ReverseMasterFile.bumped ; then
  date_echo "Error:  Cannot change file ownership"
  date_echo ""
  date_echo "Try running this script as root for correct permissions"
  exit 4
fi
chmod 644 $BackupPath/$ForwardMasterFile.bumped $BackupPath/$ReverseMasterFile.bumped
#cp -a $BackupPath/$ForwardMasterFile.new $ZonePath/$ForwardMasterFile
#cp -a $BackupPath/$ReverseMasterFile.new $ZonePath/$ReverseMasterFile

mv -f $BackupPath/$ForwardMasterFile.bumped $ZonePath/$ForwardMasterFile
mv -f $BackupPath/$ReverseMasterFile.bumped $ZonePath/$ReverseMasterFile

##########################################################################
# Reload the server config after modifications
$ZoneRootDir/script/reload.sh

date_echo "$0 complete."
exit 0
