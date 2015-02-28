##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_VirtualDevice.tcl - THC vitual device implementation
# 
# This module implements virtual devices.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Virtual devices

# Group: Setup, configuration and initialization

# Topic: Introduction
# The thc_Virtual module implements virtual devices for THC. A virtual
# device is a device that is not attached to any physical device. Virtual
# devices allow keeping control states like scenes. Virtual devices are
# initialized to 0.
#    
# Examples:
#    > DefineDevice Surveillance,state -get {thc_Virtual "Surveillance"} \
#    >                                 -set {thc_Virtual "Surveillance"}

######## Virtual device control functions ########

namespace eval thc_Virtual {

	array set DeviceStates {}

	##########################
	# DeviceSetup
	# Is called by DefineDevice each time a new virtual device is declared.
	##########################

	proc DeviceSetup {GetCmd} {
		variable DeviceStates
		set DeviceStates($GetCmd) 0
	}

	proc Get {GetCmdList} {
		variable DeviceStates
		set Result {}
		foreach GetCmd $GetCmdList {
			lappend Result $DeviceStates($GetCmd)
		}
		return $Result
	}

	proc Set {SetCmdList NewState} {
		variable DeviceStates
		foreach SetCmd $SetCmdList {
			set DeviceStates($SetCmd) $NewState
		}
		return [Get $SetCmdList]
	}

}; # end namespace thc_Virtual

return