##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_OpenWeatherMap.tcl - OpenWeatherMap
# 
# This module implements devices that get weather data from the OpenWeatherMap.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: OpenWeatherMap

# Group: Introduction and setup
#
# The thc_OpenWeatherMap module implements THC devices that get data from the 
# OpenWeatherMap site.
#
# To get weather data you need first to know a location recognized by 
# OpenWeatherMap. The location can either be defined via the city name, the 
# city ID or by the geographic coordinates. Validate the location on the 
# OpenWeatherMap website: <http://www.openweathermap.org/find?q=x>
#
# The following current weather parameters are available :
# 
# * sunrise - Sunrise time, decimal, UTC
# * sunset - Sunset time, decimal, UTC
# * temp - Temperature, Celsius
# * humidity - Humidity, %
# * pressure - Atmospheric pressure (on the sea level)
# * speed - Wind speed, km/h
# * dir - Wind direction, degrees (meteorological)
#
# The definition of an OpenWeatherMap devices requires the declaration of the
# 'get' command, using the following syntax:
#
#    > {thc_OpenWeatherMap {<Location> <WeatherParameter>}}
# 
# Examples:
#    > DefineDevice Bern,temp \
#    >    -name Bern -group Environment -format "%sC" -range {-30 50} -update 10m \
#    >    -get {thc_OpenWeatherMap {"Bern,ch" "temp"}}

######## Virtual device control functions ########

namespace eval thc_OpenWeatherMap {

	proc Get {GetCmdList} {
		# Evaluate the list of locations, together with the corresponding 
		# parameter list
		foreach GetCmd $GetCmdList {
			lappend Parameters([lindex $GetCmd 0]) [lindex $GetCmd 1]
		}
		
		# Fetch the current weather data for each location. Extract from this 
		# data the requested parameters related to the location
		foreach Location [array names Parameters] {
			# Get the current weather data for the location
			set LocationData [GetUrl "http://api.openweathermap.org/data/2.5/weather?q=$Location"]
			
			# The returned data has the following format:
			#   {
			#      "coord":{
			#         "lon":6.83,"lat":47.1},
			#      "sys":{
			#         "type":1,"id":6001,"message":0.596,"country":"CH",
			#         "sunrise":1416811772,"sunset":1416844167},
			#      "weather":
			#         [{"id":701,"main":"Mist","description":"mist","icon":"50n"}],
			#      "base":
			#         "cmc stations",
			#      "main":
			#         {"temp":281.86,"pressure":1022,"humidity":93,"temp_min":281.15,
			#          "temp_max":282.95},
			#      "wind":
			#         {"speed":1.61,"deg":73.5029},
			#      "clouds":
			#         {"all":0},
			#      "dt":1416856502,
			#      "id":2660076,
			#      "name":"La Chaux-de-Fonds",
			#      "cod":200
			#   }
			
			# Extract the requested parameters. Parse simply for the following 
			# pattern: "<AttributName" : <AttributeValue>
			# Accept zero or multiple white spaces around the column (:)
			foreach Parameter $Parameters($Location) {
				regexp "\"$Parameter\"\\s*:\\s*(\[\\d\\\.]+)" $LocationData {} Data($Location,$Parameter)
			}
		}
		
		# Build the result list. If a parameter hasn't been extracted replace it
		# by an empty string. Adjust the units for some parameters.
		foreach GetCmd $GetCmdList {
			lappend Parameters([lindex $GetCmd 0]) [lindex $GetCmd 1]
			set Res ""
			catch {
				set Res $Data([lindex $GetCmd 0],[lindex $GetCmd 1])

				# Adjust the units for some parameters
				switch [lindex $GetCmd 1] {
					sunrise -
					sunset {
						set Res [expr double($Res-[clock scan 00:00])/3600]}
					temp {
						set Res [format %.1f [expr {$Res-273.15}]]}
					speed {
						set Res [expr {$Res/1.60934}]}
				}
			}
			lappend Result $Res
		}
		return $Result
	}

}; # end namespace thc_OpenWeatherMap

return