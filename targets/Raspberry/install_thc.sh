#!/bin/sh

if [ `whoami` != "root" ]; then
	echo "You need to run this script as root (e.g. sudo $0)"
	exit 1
fi

old_thc_dir=""
if [ -d "/opt/thc" ]; then
	echo "Existing THC installation found. Stop the THC process and archive the current installation"
	/etc/init.d/thc.sh stop > /dev/null 2>&1
	old_thc_dir=/opt/thc_$(date "+%Y-%m-%d-%H-%M-%S")
	mv /opt/thc $old_thc_dir
fi

cd ~

echo "Install Tcl, RRDTools, mail send support"
sudo apt-get install tcl rrdtool-tcl rrdtool ssmtp heirloom-mailx

echo "Install THC inside /opt/thc"
wget -q -O /tmp/thc-master.zip https://github.com/Drolla/thc/archive/master.zip
unzip -d /opt /tmp/thc-master.zip
mv /opt/thc-master /opt/thc
chmod 775 /opt/thc/bin/thc.tcl
chmod 775 /opt/thc/targets/Raspberry/thc_shell_control.tcl

if [ "$old_thc_dir" != "" ]; then
	echo "Copy old THC configuration file into /opt/thc"
	cp $old_thc_dir/config.tcl /opt/thc
fi

echo "Setup THC as a service"
cd /etc/init.d
sudo cp /opt/thc/targets/Raspberry/thc.sh .
sudo chmod 775 ./thc.sh
sudo update-rc.d thc.sh defaults 98 02

echo "Create the log directory (/var/thc)"
mkdir -p /var/thc

echo "Perform the following configurations to complete the THC installation:"
echo "* Edit the THC configuration file /opt/thc/config.tcl"
echo "* Setup the mail service"
echo "* Start THC as a service:"
echo "  > /etc/init.d/thc.sh start"
