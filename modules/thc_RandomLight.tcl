##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_server.tcl - THC random light control module
# 
# This module allows an easy configuration of random light activations.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Random light control

######## RandomLight ########

namespace eval thc_RandomLight {

	catch {unset Settings}
	catch {unset DefaultDevices}
	catch {unset NextSwitchTime}

	##########################
	# Proc: thc_RandomLight::Define
	#    Defines the random control settings for one device
	#
	# Parameters:
	#    Device - Device identifier
	#    -time <OnOffTimeExpressionList> - List of 4 time values 
	#           {On1, Off1, On2, Off2} that corresponds to the light enable and
	#           disable times in the morning and the evening. The time is specified
	#           in hours and it can be an expressions (e.g. $SunriseT-0.3)
	#    [-min_interval <MinInterval> - Minimum interval time in hours. 
	#           Default is 0.5 (=30').
	#    [-probability_on <ProbabilityOn> - Value between 0 and 1 that specifies 
	#           the probability that the light is on. Default: 0.5
	#    [-default 0|1 - If set to '1' the device is considered to be switched
	#           on if no other devices is on.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > Define LightSalon,state -time {7.2 $SunriseT-0.3 $SunsetT+0.0 21.5} \
	#    >                         -min_interval 0.30 -probability_on 0.2
	#    
	# See also:
	#    <thc_RandomLight::Control>
	##########################

	proc Define {Device args} {
		variable Settings
		variable DefaultDevices
		
		array set Options {-min_interval 0.50 -probability_on 0.5 -default 0}
		array set Options $args
		Assert [info exists Options(-time)] "thc_RandomLight::Define: The option -time is mandatory!"
		Assert [info exists ::DeviceAttributes($Device,name)] "thc_RandomLight::Define: Device $Device is not defined - ignore it"
		
		set Settings($Device) [list $Options(-time) $Options(-min_interval) $Options(-probability_on) $Options(-default)]
		if {$Options(-default)} {
			lappend DefaultDevices $Device
		}
	}

	proc GetLight {args} {
		variable Settings
		
		if {$args=={}} {
			return [array names Settings]
		} else {
			foreach Device $args {
				lappend AllSettings $Settings($args)
			}
			return $AllSettings
		}
	}

	proc ControlSingleDevice {Device {Force ""}} {
		global DayTime Time NextSwitchTime State
		variable SunriseT
		variable SunsetT
		variable Settings
		
		if {![info exists SunriseT]} {
			EvaluateSunRiseSunSet
		}
		
		set MinIntervalTime [lindex $Settings($Device) 1]
		set ProbabilityOn [lindex $Settings($Device) 2]
		set On1  [lindex $Settings($Device) 0 0]
		set Off1 [lindex $Settings($Device) 0 1]
		set On2  [lindex $Settings($Device) 0 2]
		set Off2 [lindex $Settings($Device) 0 3]
		
		# Evaluate the expressions of the on and off time
		foreach var {On1 Off1 On2 Off2} {
			set $var [expr [set $var]]
		}
	
		#puts "if ($DayTime>=$On1 && $DayTime<=$Off1) || ($DayTime>=$On2 && $DayTime<=$Off2)"
		if {($DayTime>=$On1 && $DayTime<=$Off1) || ($DayTime>=$On2 && $DayTime<=$Off2)} {
			if {$Force=="0" || $Force=="1"} {
				Set $Device $Force
			} elseif {$ProbabilityOn==0.0 || $ProbabilityOn==1.0} {
				Set $Device [expr round($ProbabilityOn)]
			} elseif {![info exists NextSwitchTime($Device)] || $Time>$NextSwitchTime($Device)} {
				if {$State($Device)==1} {
					Set $Device 0
					set NextSwitchTime($Device) [expr {$Time+(1.0-$ProbabilityOn)*(0.3+1.4*rand())*$MinIntervalTime*3600.0}]
				} else {
					Set $Device 1
					set NextSwitchTime($Device) [expr {$Time+($ProbabilityOn)*(0.3+1.4*rand())*$MinIntervalTime*3600.0}]
				}
			}
		} elseif {![info exists State($Device)] || $State($Device)!=0} {
			Set $Device 0
			catch {unset NextSwitchTime($Device)}
		}
		return [expr {[info exists State($Device)] && $State($Device)==1}]
	}

	##########################
	# Proc: thc_RandomLight::Control
	#    Applies random settings to the lights
	#
	# Parameters:
	#    [Force] - If define the lights are set to this value (needs to be 0 or 1).
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > DefineJob -tag RdmLight -repeat 1m -description "Random light" {
	#    >    thc_RandomLight::Control}
	#
	#    > thc_RandomLight::Control 0
	#    
	# See also:
	#    <thc_RandomLight::Define>
	##########################


	# Control [Force] - Force="": Random, Force=0/1: Force off/on
	proc Control { {Force ""} } {
		global State
		variable DefaultDevices
		variable Settings

		# Random light Control - No alarm
		if {$Force!=""} {
			Set [array names Settings] $Force
		} else {
			set NbrLightsOn 0
			foreach Device [array names Settings] {
				incr NbrLightsOn [ControlSingleDevice $Device]
			}
			if {!$NbrLightsOn} {
				ControlSingleDevice [lindex $DefaultDevices [expr int(rand()*13567)%[llength $DefaultDevices]]] 1
			}
			Log {Random light control switch} 1
		}
	}

	##########################
	# Proc: thc_RandomLight::EvaluateSunRiseSunSet
	#    Evaluates sun rise and set time. These two times are stored 
	#    respectively inside the variables SunriseT and SunsetT. The
	#    following variables need to be defined for the sun time calculation:
	#
	#   > Longitude - Geographical longitude
	#   > Latitude - Geographical latitude
	#   > Zone - Time zone in hours (e.g. +2). If set to 'auto' or '' the time 
	#            zone will be automatically evaluated
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > namespace eval thc_RandomLight {
	#    >   set Longitude 6.8250
	#    >   set Latitude 47.1013
	#    >   set Zone auto }
	#    >
	#    > DefineJob -tag EvalSun -time 01h -repeat 24h -init_time +0 \
	#    >           -description "Evaluate the sun shine time" {
	#    >    thc_RandomLight::EvaluateSunRiseSunSet}
	#    
	# See also:
	#    <thc_RandomLight::Define>
	##########################

	proc EvaluateSunRiseSunSet {} {
		global Longitude Latitude Zone Time SunriseT SunsetT
		variable Longitude
		variable Latitude
		variable Zone
		variable SunriseT
		variable SunsetT

		# Some constants
		set pi 3.1415926536
		set RAD [expr {$pi/180.0}]; # Factor Grad to  radian
		set h [expr {-(50.0/60.0)*$RAD}]; # Sun center hight at sunrise/set: Radius+Refraction
		
		set B [expr {$Latitude*$RAD}]; # Geographical latitude in radian
		set T [string trimleft [clock format $Time -format %j] 0]; # Day in the year

		# Set the time zone time shift. Determine it automatically if Zone is set to 'auto' or ''
		set ZoneShift $Zone
		if {$ZoneShift=="" || $ZoneShift=="auto"} {
			set ZoneShift [clock format [clock seconds] -format %z];           # e.g. +0200, -1200
			set ZoneShift [regsub {^([-+])0{0,1}(\d+)\d\d$} $ZoneShift {\1\2}]; # e.g. 2, -12
		}
		
		# Sun declination in radian
		# Formula 2008 by Arnold(at)Barmettler.com, fit to 20 years of average declinations (2008-2017)
		set Declination [expr {0.409526325277017*sin(0.0169060504029192*($T-80.0856919827619))}]
		
		# Half day duration in hours: Time from sunrise to highest sun position most in the south
		set TimeDifference [expr {12.0*acos((sin($h) - sin($B)*sin($Declination)) / (cos($B)*cos($Declination)))/$pi}]
		
		# Difference between true and mean sun time
		# Formula 2008 by Arnold(at)Barmettler.com, fit to 20 years of average equation of time (2008-2017)
		set TimeEquation [expr {-0.170869921174742*sin(0.0336997028793971*$T + 0.465419984181394) - 0.129890681040717*sin(0.0178674832556871*$T - 0.167936777524864)}]
		
		# Sunrise and sunset calculations
		set SunRise0 [expr {12 - $TimeDifference - $TimeEquation}]; # Sunrise at 0° Longitude
		set SunriseT [expr {$SunRise0 - $Longitude/15.0 + $ZoneShift}]; # Sunrise at specified Longitude and time zone in hours
		set SunSet0 [expr {12 + $TimeDifference - $TimeEquation}]; # Sunset at 0° Longitude
		set SunsetT  [expr {$SunSet0 - $Longitude/15.0 + $ZoneShift}]; # Sunset at specified Longitude and time zone in hours

		Log [format "thc_RandomLight - Sunrise:%2ih%2i, sunset:%2ih%2i (zone %d)" [expr int($SunriseT)] [expr int($SunriseT*60)%60] [expr int($SunsetT)] [expr int($SunsetT*60)%60] $ZoneShift] 2
	}

}; # end namespace thc_RandomLight