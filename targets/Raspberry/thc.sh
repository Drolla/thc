#!/bin/sh
### BEGIN INIT INFO
# Provides:       thc
# Required-Start: $network $remote_fs $syslog $time $Z-Way
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:  0 1 6
# Short-Description: TightHomeControl
# Description:     Start/stop TightHomeControl service
### END INIT INFO

#PATH=/bin:/usr/bin:/sbin:/usr/sbin
NAME=thc.tcl
DAEMON_PATH=/opt/thc/bin
LOGFILE=/var/thc/thc.log
PIDFILE=/var/run/thc.pid

case "$1" in
  start)
	echo -n "Starting thc: "
	start-stop-daemon --start  --pidfile $PIDFILE --make-pidfile  --background --no-close --chdir $DAEMON_PATH --exec $NAME >> $LOGFILE 2>&1
	echo "done."
	;;
  stop)
	echo -n "Stopping TightHomeControl: "
	start-stop-daemon --stop --quiet --pidfile $PIDFILE
	rm $PIDFILE
	echo "done."
	;;
  restart)
	echo "Restarting TightHomeControl: "
	sh $0 stop
	sleep 10
	sh $0 start
	;;
  save)
	echo "Saving TightHomeControl configuration"
	PID=`sed s/[^0-9]//g $PIDFILE`
	/bin/kill -10 $PID
	;;
  *)
	echo "Usage: /etc/init.d/thc.sh {start|stop|restart|save}"
	exit 1
	;;
esac
exit 0

