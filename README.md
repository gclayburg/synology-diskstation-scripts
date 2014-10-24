synology-diskstation-scripts
============================

Scripts that help with Synology Diskstation maintenance


##diskstation_dns_modify.sh

This script can be used to configure a synology diskstation to automatically update its internal DNS records from its internal DHCP server.  As of 2014-10-20 Synology Diskstation DSM cannot do this from the GUI.

###installation
See the original documentation for installation instructions and/or review the script comments to see what it does.


The script originated here:

http://forum.synology.com/enu/viewtopic.php?f=233&t=88517

Original docs:

https://www.youtube.com/watch?v=T22xytAWq3A&list=UUp8GcSEeUnLY8d6RAT6Y3Mg


###changelog

2014-10-20  Modifed to honor DNS static IP addresses

For example, lets say you have configured DNS in synology DSM.  You are manually assigning static IP addresses using the DSM GUI in the range of 192.168.1.1 - 192.168.1.99.  You have also configured Synology DHCP to server dynamic IP addresses starting at 192.168.1.100.  This is all works fine.  However, without this script here, Synology will not update DNS records when the DHCP server assigns a new dynamic IP address.  This script does that and it now does it without overwriting static DNS entries in the range of 192.168.1.1 - 192.168.1.99

####Deployment

You will need to:

1. Copy this script into the "admin" account
2. Edit this script to match your settings
3. Setup a recurring task in Synology DSM to run the script at regular intervals

The exact steps for this are outlined in great detail in the links provided above
