##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_MeteoSwiss.tcl - MeteoSwiss
# 
# This module implements devices that get weather data from the MeteoSwiss
# via the SwissMetNet data portal
# (see: http://opendata.admin.ch/en/dataset/messdatensmn).
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: MeteoSwiss

# Group: Introduction and setup
#
# The thc_MeteoSwiss module implements THC devices that get data from 
# SwissMetNet. For details about the data portal, see 
# http://opendata.admin.ch/en/dataset/messdatensmn.
#
# To get weather data you need first to know the abbreviation of the location
# you are interested in. For this open data legend file http://data.geo.admin.ch.s3.amazonaws.com/ch.meteoschweiz.swissmetnet/03-10min_Daten_legenden.zip.
# 
# The following current weather parameters are available :
#
# * temperature - Air temperature 2 m above ground; current value (°C)
# * humidity - Relative air humidity 2 m above ground; current value (%)
# * pressure - Pressure reduced to sea level according to standard atmosphere (QNH); current value (hPa)
# * speed - Wind speed; ten minutes mean (km/h)
# * direction - Wind direction; ten minutes mean (°)
# * precipitation - Precipitation; ten minutes total (mm)
#
# The definition of an MeteoSwiss devices requires the declaration of the
# 'get' command, using the following syntax:
#
#    > {thc_MeteoSwiss {<LocationAbbreviation> <WeatherParameter>}}
# 
# Examples:
#    > DefineDevice Bern,temp \
#    >    -name Bern -group Environment -format "%sC" -range {-30 50} -update 10m \
#    >    -get {thc_MeteoSwiss {"BER" "temperature"}}

######## Virtual device control functions ########

namespace eval thc_MeteoSwiss {

	array set ParameterNames {
		temperature tre200s0
		precipitation rre150z0
		direction dkl010z0
		speed fu3010z0
		pressure pp0qnhs0
		humidity ure200s0
	}

	proc Get {GetCmdList} {
		variable ParameterNames
		
		# Fetch the current weather data
		# Get the current weather data for the location
		catch {
			set LocationResponse [GetUrl "http://data.geo.admin.ch.s3.amazonaws.com/ch.meteoschweiz.swissmetnet/VQHA69.txt"]
			set LocationData [lindex $LocationResponse 2]
		}
			
		# The returned data has the following format:
		# :  
		# :  MeteoSchweiz / MeteoSuisse / MeteoSvizzera / MeteoSwiss
		# :  
		# :  stn|time|tre200s0|sre000z0|rre150z0|dkl010z0|fu3010z0|pp0qnhs0|fu3010z1|ure200s0|prestas0|pp0qffs0
		# :  TAE|201411301700|2.0|0|0.0|62|5.0|1009.2|10.4|99|946.3|1011.2
		# :  COM|201411301700|9.3|0|0.1|155|5.0|1011.6|6.8|97|944.3|1011.8
		# :  ABO|201411301700|8.9|0|0.0|340|1.8|1008.7|3.2|62|859.7|-
		# :  AIG|201411301700|7.7|0|0.0|250|0.7|1008.6|1.8|89|963.7|1009.2
		# :  ...
		
		# Identify the position of the different fields
		catch {
			set Fields [split [regexp -inline -line {^.*\ystn\y.*$} $LocationData] "|"]
		}
		
	 	# Extract from the data the requested parameters for the different 
	 	# locations
		foreach GetCmd $GetCmdList {
			set Res ""
			catch {
				set Location [lindex $GetCmd 0]
				set Parameter [lindex $GetCmd 1]
				set DataSet [split [regexp -inline -line "^$Location.*$" $LocationData] "|"]
				set Res [lindex $DataSet [lsearch -exact $Fields $ParameterNames($Parameter)]] 
			}
			lappend Result $Res
		}
		
		return $Result
	}

}; # end namespace thc_MeteoSwiss

return