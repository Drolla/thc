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

namespace eval ::thc::RandomLight {

	##########################
	# Proc: thc::RandomLight::Configure
	#    Configures the geographical location and time zone.
	#
	# Parameters:
	#    [-longitude <Longitude> - Geographical longitude
	#    [-latitude <Latitude> - Geographical latitude
	#    [-zone <Zone>] - Time zone in hours (e.g. +2). If set to 'auto' or '' 
	#                     the time zone will be automatically evaluated. 
	#                     Default: 'auto'
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc::RandomLight::Configure \
	#    >    -longitude 6.8250 -latitude 47.1013 -zone "auto"
	#    
	# See also:
	#    <thc::RandomLight::Define>
	##########################

	variable Config
	array set Config {
		-longitude ""
		-latitude ""
		-zone "auto"
	}

	proc Configure {args} {
		variable Config
		
		if {$args=={}} {
			return [array get Config]
		} elseif {[llength $args]==1} {
			return $Config($args)
		} else {
			array set Config $args
		}
	}

	variable Settings
		catch {unset Settings}
	variable DefaultDevices
		catch {unset DefaultDevices}
	variable NextSwitchTime
		catch {unset NextSwitchTime}

	##########################
	# Proc: thc::RandomLight::Define
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
	#    > thc::RandomLight::Define LightSalon,state \
	#    >            -time {7.2 $SunriseT-0.3 $SunsetT+0.0 21.5} \
	#    >            -min_interval 0.30 -probability_on 0.2
	#    
	# See also:
	#    <thc::RandomLight::Control>
	##########################

	proc Define {Device args} {
		variable Settings
		variable DefaultDevices
		
		array set Options {-min_interval 0.50 -probability_on 0.5 -default 0}
		array set Options $args
		::thc::Assert [info exists Options(-time)] "thc::RandomLight::Define: The option -time is mandatory!"
		::thc::Assert [info exists ::thc::DeviceAttributes($Device,Name)] "thc::RandomLight::Define: Device $Device is not defined - ignore it"
		
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
		variable SunriseT
		variable SunsetT
		variable Settings
		variable NextSwitchTime
		upvar #0 thc::Time Time
		upvar #0 thc::DayTime DayTime
		upvar #0 thc::State State
		
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
				::thc::Set $Device $Force
			} elseif {$ProbabilityOn==0.0 || $ProbabilityOn==1.0} {
				::thc::Set $Device [expr round($ProbabilityOn)]
			} elseif {![info exists NextSwitchTime($Device)] || $Time>$NextSwitchTime($Device)} {
				if {$State($Device)==1} {
					::thc::Set $Device 0
					set NextSwitchTime($Device) [expr {$Time+(1.0-$ProbabilityOn)*(0.3+1.4*rand())*$MinIntervalTime*3600.0}]
				} else {
					::thc::Set $Device 1
					set NextSwitchTime($Device) [expr {$Time+($ProbabilityOn)*(0.3+1.4*rand())*$MinIntervalTime*3600.0}]
				}
			}
		} elseif {![info exists State($Device)] || $State($Device)!=0} {
			::thc::Set $Device 0
			catch {unset NextSwitchTime($Device)}
		}
		return [expr {[info exists State($Device)] && $State($Device)==1}]
	}

	##########################
	# Proc: thc::RandomLight::Control
	#    Applies random settings to the lights
	#
	# Parameters:
	#    [Force] - If define the lights are set to this value (needs to be 0 or 1).
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc::DefineJob -tag RdmLight -repeat 1m -description "Random light" {
	#    >    thc::RandomLight::Control }
	#
	#    > thc::RandomLight::Control 0
	#    
	# See also:
	#    <thc::RandomLight::Define>
	##########################


	# Control [Force] - Force="": Random, Force=0/1: Force off/on
	proc Control { {Force ""} } {
		variable DefaultDevices
		variable Settings

		# Random light Control - No alarm
		if {$Force!=""} {
			::thc::Set [array names Settings] $Force
		} else {
			set NbrLightsOn 0
			foreach Device [array names Settings] {
				incr NbrLightsOn [ControlSingleDevice $Device]
			}
			if {!$NbrLightsOn} {
				ControlSingleDevice [lindex $DefaultDevices [expr int(rand()*13567)%[llength $DefaultDevices]]] 1
			}
			::thc::Log {Random light control switch} 1
		}
	}

	##########################
	# Proc: thc::RandomLight::EvaluateSunRiseSunSet
	#    Evaluates sun rise and set time. These two times are stored 
	#    respectively inside the variables SunriseT and SunsetT. The
	#    geographical location and time zone has to be defined to use this
	#    function.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > ::thc::RandomLight::Configure \
	#    >                        -longitude 6.8250 -latitude 47.1013 -zone auto
	#    >
	#    > thc::DefineJob -tag EvalSun -time 01h -repeat 24h -init_time +0 \
	#    >                -description "Evaluate the sun shine time" {
	#    >    thc::RandomLight::EvaluateSunRiseSunSet }
	#    
	# See also:
	#    <thc::RandomLight::Configure> <thc::RandomLight::Define>
	##########################

	proc EvaluateSunRiseSunSet {} {
		variable Config
		variable SunriseT
		variable SunsetT
		upvar #0 thc::Time Time

		# Some constants
		set pi 3.1415926536
		set RAD [expr {$pi/180.0}]; # Factor Grad to  radian
		set h [expr {-(50.0/60.0)*$RAD}]; # Sun center hight at sunrise/set: Radius+Refraction
		
		set B [expr {$Config(-latitude)*$RAD}]; # Geographical latitude in radian
		set T [string trimleft [clock format $Time -format %j] 0]; # Day in the year

		# Set the time zone time shift. Determine it automatically if Zone is set to 'auto' or ''
		set ZoneShift $Config(-zone)
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
		set SunriseT [expr {$SunRise0 - $Config(-longitude)/15.0 + $ZoneShift}]; # Sunrise at specified Longitude and time zone in hours
		set SunSet0 [expr {12 + $TimeDifference - $TimeEquation}]; # Sunset at 0° Longitude
		set SunsetT  [expr {$SunSet0 - $Config(-longitude)/15.0 + $ZoneShift}]; # Sunset at specified Longitude and time zone in hours

		::thc::Log [format "thc_RandomLight - Sunrise:%2ih%2i, sunset:%2ih%2i (zone %d)" [expr int($SunriseT)] [expr int($SunriseT*60)%60] [expr int($SunsetT)] [expr int($SunsetT*60)%60] $ZoneShift] 2
	}

}; # end namespace thc_RandomLight

return