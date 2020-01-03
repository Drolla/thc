##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_MultiBinarySwitch.tcl - THC multi binary switch
# 
# This module implements multi binary switch devices.
#
# Copyright (C) 2017 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Multi binary switch devices

# Group: Setup, configuration and initialization

# Topic: Introduction
#    The multi binary switch device allows controlling multiple binary switch
#    devices as a single multi-level switch. The binary switch devices have
#    already to be defined.
#
# Examples:
#    > thc::DefineDevice FanCellar,state \
#    >    -name FanCellar -group  -type switch \
#    >    -get {thc_MultiBinarySwitch {FanCellarSW1,state FanCellarSW2,state}} \
#    >    -set {thc_MultiBinarySwitch {FanCellarSW1,state FanCellarSW2,state}}

######## Multi level device control functions ########

namespace eval ::thc::MultiBinarySwitch {

	proc Get {DeviceListList} {
		set Result {}
		foreach DeviceList $DeviceListList {
			set Res 0
			foreach Device [lreverse $DeviceList] {
				set v 0
				catch {set v $::thc::State($Device)}
				set Res [expr {($Res<<1) | ($v!=0)}]
			}
			lappend Result $Res
		}
		return $Result
	}

	proc Set {DeviceListList NewState} {
		foreach DeviceList $DeviceListList {
			set v [expr {round($NewState)}]
			foreach Device $DeviceList {
				::thc::Set $Device [expr {$v%2}]
				set v [expr {$v>>1}]
			}
		}
		return $NewState
	}

}; # end namespace thc_MultiBinarySwitch

return