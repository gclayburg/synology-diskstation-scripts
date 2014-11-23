synology-diskstation-scripts
============================

Scripts that help with Synology Diskstation maintenance



Why do I need this?
tl;dr version:  You are running Synology Diskstation DNS and DHCP services and you want dynamic DHCP reservations to update DNS immediately.

Synology Diskstation has an embedded DNS server that can be enabled for your network.  This does the standard thing of resolving hostnames to IP addresses.  So, lets say you have a VMware ESXi server on your local network. You arbitrarily name it esxi1.homelan.net.   The DNS server is where you map the name esxi1.homelan.net to the static IP address of 192.168.1.10.  From then on, all other devices in your network can access this server using the name esxi.homelan.net.  Only the DNS server needs to remember the IP address.  Nothing new here.

Synology diskstation also has a DHCP server that you can use to dynamically assign IP addreses to hosts on your network.  This means you can power up a new laptop,ipad, or guest VM on your network and it will be able to use the network without configuring anything.  Under the covers, they use DHCP to get an available IP address from your DHCP server.

Synology can host both of these services and they both work well by themselves.  However, they don't talk to each other.  They both deal with IP addresses and hostnames, yet they operate independently.  For example, when you power on your laptop, the laptop will essentially say something like this:  "Hello, my hostname is garylaptop and I need an available IP address".  The DHCP server will gladly assign an unused IP address, but that is where things end.  The DNS server knows nothing about this hostname to IP address assignment.  This means that no other host on the network will be able to refer to the laptop if they only know the hostname.  You can't, for example, do something like "ssh garylaptop" from another host on your network.

For the average consumer client device like a laptop or ipad, this is normally fine.  It is unlikely that other devices on the network want to communicate with the laptop using a hostname.

This becomes more of an issue when you have more devices and servers running on your network.  The default for most new servers and clients is to use DHCP to get an IP address.  This makes things simpler for setting up that new linux distribution, but gets in the way when you want to experimient with some server software on there.  One approach is to manually assign a static IP address and create a static DNS entry for this new server.  This is somethign you would want to do if you know you want to keep that server around for a while.  But if you are just messing around with something new, it is quite handy to have all of this taken care of for you.  This is where this project comes in.

##diskstation_dns_modify.sh

This script can be used to configure a synology diskstation to automatically update its internal DNS records from its internal DHCP server.  As of 2014-10-20 Synology Diskstation DSM cannot do this from the GUI.

###installation
This script must be edited to match your network.  See the original documentation for installation instructions and/or review the script comments to see what it does.


The script originated here:

http://forum.synology.com/enu/viewtopic.php?f=233&t=88517

Original docs:

https://www.youtube.com/watch?v=T22xytAWq3A&list=UUp8GcSEeUnLY8d6RAT6Y3Mg


###changelog

2014-10-20  Modifed to honor DNS static IP addresses

For example, lets say you have configured DNS in synology DSM.  You are manually assigning static IP addresses using the DSM GUI in the range of 192.168.1.1 - 192.168.1.99.  You have also configured Synology DHCP to serve dynamic IP addresses starting at 192.168.1.100.  This is all works fine.  However, without this script here, Synology will not update DNS records when the DHCP server assigns a new dynamic IP address.  This script does that and it now does it without overwriting static DNS entries in the range of 192.168.1.1 - 192.168.1.99

2014-11-10  Fixed a bug where DNS update would fail if DHCP client does not specify a hostname

2014-11-23  A new script is available to update DNS within 10 seconds of a new DHCP reservation

####Deployment

You will need to:

1. Copy this script into the "admin" account
2. Edit this script to match your settings
3. Setup a recurring task in Synology DSM to run the script at regular intervals

The exact steps for this are outlined in great detail in the links provided above
