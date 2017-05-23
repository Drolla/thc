#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}
##########################################################################
# THC - Tight Home Control
##########################################################################
# RrdManip.tcl - THC RRD database manipulation
# 
# This program allows manipulating THC RRD databases.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: THC RRD database manipulation utility
#
# RrdManip.tcl allows manipulating Rrd databases used by THC. It requires that 
# Tcl 8.5 or above is installed as well as the Rrd tools.
#
# RrdManip.tcl is stored inside the modules/thc_Rrd directory. It needs to  
# have execution privileges to run it.
#
# Syntax:
#
#  > RrdManip.tcl list   <RrdDatabaseFile>
#
#  > RrdManip.tcl add    <RrdDatabaseFile> <Device1> <Device2> ...
#
#  > RrdManip.tcl rename <RrdDatabaseFile> <Device1OldName> <Device1NewName> \
#  >                                       <Device2OldName> <Device2NewName> ...
#
#  > RrdManip.tcl remove <RrdDatabaseFile> <Device1> <Device2> ...
#
#  > RrdManip.tcl modif <RrdDatabaseFile> <Device> <Expression>
#  >                    [-from <FromTime>] [-to <ToTime>]
#  > (the expression has to refer the original value with '$Value')
#
#  > RrdManip.tcl range <RrdDatabaseFile> <Device> <LowLimit> <HighLimit>
#  >                    [-from <FromTime>] [-to <ToTime>]
#
# Description:
# 
# RrdManip.tcl can _list_, _add_, _rename_ or _remove_ devices from/to an existing THC
# RRD database, as well as modify stored device values. The provided device 
# names are converted into RRD conform names (e.g. device names truncated to 19 
# characters, ',' replaced by '_').
#
# If the _-from_ and/or _-to_ option is provided the device value modification 
# is performed only in a certain time range. The _FromTime_ and _ToTime_ 
# arguments have to correspond to valid Tcl time expressions.
# 
# Examples:
#   > chmod 777 /opt/thc/modules/thc_Rrd/RrdManip.tcl
#   >
#   > /opt/thc/modules/thc_Rrd/RrdManip.tcl list   /var/thc/thc.rrd
#   > /opt/thc/modules/thc_Rrd/RrdManip.tcl add    /var/thc/thc.rrd Light,Living Light,Cellar
#   > /opt/thc/modules/thc_Rrd/RrdManip.tcl rename /var/thc/thc.rrd Light,Cellar Light,Basement
#   > /opt/thc/modules/thc_Rrd/RrdManip.tcl remove /var/thc/thc.rrd Light,Living Light,Basement
#   > /opt/thc/modules/thc_Rrd/RrdManip.tcl modif  /var/thc/thc.rrd Temp,Living '$Value+0.3' \
#   >                                              -from {Jun 27 06:01:00 CEST 2016}
#   > /opt/thc/modules/thc_Rrd/RrdManip.tcl range  /var/thc/thc.rrd Temp,Living 10 35 \
#   >                                              -from "2016-06-27 06:01:00 CEST" \
#   >                                              -to "2016-06-27 07:00:00 CEST"


######## Help ########

	proc Help {} {
		puts ""
		puts "Syntax:"
		puts "  RrdManip.tcl <Command> <Options>"
		puts ""
		puts "  Commands: list add rename remove"
		puts ""
		puts "  RrdManip.tcl list   <RrdDatabaseFile>"
		puts "  RrdManip.tcl add    <RrdDatabaseFile> <Device1> <Device2> ..."
		puts "  RrdManip.tcl rename <RrdDatabaseFile> <Device1OldName> <Device1NewName> <Device2OldName> <Device2NewName> ..."
		puts "  RrdManip.tcl remove <RrdDatabaseFile> <Device1> <Device2> ..."
		puts "  RrdManip.tcl modif  <RrdDatabaseFile> <Device> <Expression> \\"
		puts "                      \[-from <FromTime>\] \[-to <ToTime>\]"
		puts "                      (the expression has to refer the original value with '\$Value')"
		puts "  RrdManip.tcl range  <RrdDatabaseFile> <Device> <LowLimit> <HighLimit> \\"
		puts "                      \[-from <FromTime>\] \[-to <ToTime>\]"
		puts ""
		puts "Examples:"
		puts "  RrdManip.tcl list   /var/thc/thc.rrd"
		puts "  RrdManip.tcl add    /var/thc/thc.rrd Light,Living Light,Cellar"
		puts "  RrdManip.tcl rename /var/thc/thc.rrd Light,Cellar Light,Basement"
		puts "  RrdManip.tcl remove /var/thc/thc.rrd Light,Living Light,Basement"
		puts "  RrdManip.tcl modif  /var/thc/thc.rrd Temp,Living '\$Value+0.3' \\"
		puts "                      -from \"Jun 27 06:01:00 CEST 2016\""
		puts "  RrdManip.tcl range  /var/thc/thc.rrd Temp,Living 10 35 \\"
		puts "                      -from \"2016-06-27 06:01:00 CEST\" \\"
		puts "                      -to \"2016-06-27 07:00:00 CEST\""
		puts ""
		exit
	}

######## Perform the requested manipulation ########
	
	source [file dirname [info script]]/thc_Rrd.tcl

	if {[llength $argv]<2} Help
	
	set RrdFile [lindex $argv 1]
	if {![file exists $RrdFile]} {
		puts "File $RrdFile doesn't exist"
		exit
	}
	
	time {
	switch [lindex $argv 0] {
		list    {puts [thc_Rrd::RrdGetDeviceList $RrdFile]}
		add     {puts [thc_Rrd::RrdAddDevices $RrdFile [lrange $argv 2 end]]}
		rename  {puts [thc_Rrd::RrdRenameDevices $RrdFile [lrange $argv 2 end]]}
		remove  {puts [thc_Rrd::RrdRemoveDevices $RrdFile [lrange $argv 2 end]]}
		modif   {puts [thc_Rrd::RrdModifyDeviceValues $RrdFile {*}[lrange $argv 2 end]]}
		range   {puts [thc_Rrd::RrdCheckDeviceValueRange $RrdFile {*}[lrange $argv 2 end]]}
		default {Help}
	}
	}
