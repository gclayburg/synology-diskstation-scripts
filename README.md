synology-diskstation-scripts
============================

Scripts that help with Synology Diskstation maintenance



##Why do I need this?

#tl;dr version:  
You are running Synology Diskstation DNS and DHCP services and you want dynamic DHCP reservations to update DNS immediately.

#Background
Synology Diskstation has an embedded DNS server that can be enabled for your network.  This does the standard thing of resolving hostnames to IP addresses.  So, lets say you have a VMware ESXi server on your local network. You arbitrarily name it `esxi1.homelan.net`.   The DNS server is where you map the name `esxi1.homelan.net` to the static IP address of `192.168.1.10`.  From then on, all other devices in your network can access this server using the name `esxi.homelan.net`.  Only the DNS server needs to remember the IP address.  Nothing new here.

Synology diskstation also has a DHCP server that you can use to dynamically assign IP addreses to hosts on your network.  This means you can power up a new laptop, ipad, or guest VM on your network and it will be able to use the network without configuring anything.  Under the covers, they use DHCP to get an available IP address from your DHCP server.

Synology can host both of these services and they both work well by themselves.  However, they don't talk to each other.  They both deal with IP addresses and hostnames, yet they operate independently.  For example, when you power on your laptop, the laptop will essentially say something like this:  "Hello, my hostname is `garylaptop` and I need an available IP address".  The DHCP server will gladly assign an unused IP address, but that is where things end.  The DNS server knows nothing about this hostname to IP address assignment.  This means that no other host on the network will be able to refer to the laptop if they only know the hostname.  You can't, for example, do something like `ssh garylaptop` from another host on your network.

For the average consumer client device like a laptop or ipad, this is normally fine.  It is unlikely that other devices on the network want to communicate with the laptop using a hostname.

This becomes more of an issue when you have more devices and servers running on your network.  The default for most new servers and clients is to use DHCP to get an IP address.  This makes things simpler for setting up that new linux distribution, but gets in the way when you want to experimient with some server software on there.  One approach is to manually assign a static IP address and create a static DNS entry for this new server.  This is something you would want to do if you know you want to keep that server around for a while.  But if you are just messing around with something new, it is quite handy to have all of this taken care of for you.  This is where this project comes in.

##diskstation_dns_modify.sh

This script can be used to configure a synology diskstation to automatically update its internal DNS records from its internal DHCP server.  As of 2014-10-20 Synology Diskstation DSM cannot do this from the GUI.

###Credit

The script originated from Tim Smith here:

http://forum.synology.com/enu/viewtopic.php?f=233&t=88517

Original docs:

https://www.youtube.com/watch?v=T22xytAWq3A&list=UUp8GcSEeUnLY8d6RAT6Y3Mg


###changelog

2014-10-20  Modified to honor DNS static IP addresses

For example, lets say you have configured DNS in synology DSM.  You are manually assigning static IP addresses using the DSM GUI in the range of `192.168.1.1` - `192.168.1.99`.  You have also configured Synology DHCP to serve dynamic IP addresses starting at `192.168.1.100`.  This is all works fine.  However, without this script here, Synology will not update DNS records when the DHCP server assigns a new dynamic IP address.  This script does that and it now does it without overwriting static DNS entries in the range of `192.168.1.1` - `192.168.1.99`.

2014-11-10  Fixed a bug where DNS update would fail if DHCP client does not specify a hostname

2014-11-23  A new script is available to update DNS within 10 seconds of a new DHCP reservation

2015-05-01  DHCP leases in `/etc/dhcpd/dhcpd.conf.leases` are now supported.  

2015-08-13  A new script is available to start this service each time the synology diskstation boots up.  You no longer need to have any Task Scheduler items when using this script 

2015-08-13  Updated documentation

2015-08-13  Updated file path in scripts to match a more generic location of the admin account directory.

2016-04-18  Fixed issue [#5](https://github.com/gclayburg/synology-diskstation-scripts/issues/5) (script output would redirect to the wrong place)

2016-04-18  Fixed issue [#6](https://github.com/gclayburg/synology-diskstation-scripts/issues/6) (documentation)

2016-04-18  Fixed issue [#7](https://github.com/gclayburg/synology-diskstation-scripts/issues/7) (added new lease file location for DSM 6.0)

2016-09-17  log file now prints out more debug information about both static and dynamic addresses populated into DNS records

2016-09-17  S99pollDHCP.sh should now work correctly under both DSM 5 and DSM 6

2016-09-17  Fixed issue [#11](https://github.com/gclayburg/synology-diskstation-scripts/issues/11) Serial # is now updated for DNS zone master forward and reverse files

####Deployment

You will need to:

1. Install two scripts into the "admin" account.  These scripts should be owned by root and executable:

    ```
    DiskStation> ls -l /var/services/homes/admin/*sh
    -rwxr-xr-x    1 root     root          7798 May  1 15:07 /var/services/homes/admin/diskstation_dns_modify.sh
    -rwxr-xr-x    1 root     root           283 Nov 21  2014 /var/services/homes/admin/poll-dhcp-changes.sh
    ```
   These scripts do not need to be modified.

2. Install the settings file to the admin directory:

    ```
    DiskStation> ls -l /var/services/homes/admin/settings                              
    -rw-r--r--    1 root     root           109 Sep 24  2015 /var/services/homes/admin/settings
    ```

    The settings file needs to be modified to match your network.  See the comments in the `diskstation_dns_modify.sh` script for details.

3. Install the start script into `/usr/local/etc/rc.d/ directory`.  It also should be owed by root and executable.

```
DiskStation> ls -l /usr/local/etc/rc.d
-rwxr-xr-x    1 root     root           693 Aug  6 13:40 S99pollDHCP.sh
```

This `S99pollDHCP.sh` script will be called during the Synology DSM boot process the next time the server is restarted.  This script can also be started manually:

```
DiskStation> /usr/local/etc/rc.d/S99pollDHCP.sh start
```

and stopped:

```
DiskStation> /usr/local/etc/rc.d/S99pollDHCP.sh stop
```

__Warning__ If you manually start the server manually like this, this script will only run while you are logged on to the ssh console.  The script will stop once you log off.  DNS will not be updated from new reservations until this script is started again.  To run the script permanently, you will need to reboot your Synology Diskstation.   This is because there is no "nohup" command in the standard Synology DSM.  


####Starting via Task Scheduler
If it is inconvenient to restart your Synology Diskstation, there is an alternate way to start this service using the DSM Task Scheduler (Main Menu -> Control Panel -> Task Scheduler).  The script will run indefinitely when started this way.  This is basically a way to simulate "nohup" without going down the path of installing extra software on Synology DSM just to avoid having to do a reboot the first time the software is installed.

1.  Open Task Scheduler
2.  Click Create -> User-defined script
3.  Key in a name for the task.  Anything is fine here.
4.  Uncheck the "Enabled" button.  You don't want this task to start this service over and over on some schedule.  We are just going to use the task scheduler to start our service one time.
5.  Key in this in the User-defined script area and click OK:

```sh
        /usr/local/etc/rc.d/S99pollDHCP.sh start >>/var/services/homes/admin/startS99pollDHCP.log
```

You can now select the script from the list and Click run.  Boom.  Done.

####Troubleshooting

Each time this script detects that that there is a DHCP change, DNS will be updated.  It may take up to 10 seconds for DNS to be updated after a new DHCP reservation.  A log file of this process is kept at `/var/services/homes/admin/logs/dhcp-dns.log`.  

You can also view the DNS log from the normal DSM UI.  This can be useful if there is some sort of conflict between static DNS entries that you defined in the DSM DNS UI and new DHCP hostnames.

