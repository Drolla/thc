#!/bin/sh

if [ `whoami` != "root" ]; then
	echo "You need to run this script as root (e.g. sudo $0)"
	exit 1
fi

cd ..

echo "Stop TightHomeControl service"
/etc/init.d/thc.sh stop > /dev/null 2>&1

echo "Copy thc.sh to etc/init.d, and register the service"
cp bin/thc.sh /etc/init.d
chmod 775 /etc/init.d/thc.sh
update-rc.d thc.sh defaults


  > cd /etc/init.d
  > sudo cp /opt/thc/targets/Raspberry/thc.sh .
  > sudo chmod 775 ./thc.sh
  > sudo update-rc.d thc.sh defaults 98 02

echo "Install the TightHomeControl run directory (/opt/thc)"
mkdir -p /opt/thc
cp -r ../.. /opt
chmod 775 /opt/thc/bin/thc.tcl
chmod 775 /opt/thc/targets/Raspberry/thc_shell_control.tcl

echo "Create the log directory (/var/thc)"
mkdir -p /var/thc

echo "Start TightHomeControl service"
/etc/init.d/thc.sh start
