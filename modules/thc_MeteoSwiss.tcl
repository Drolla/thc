##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_MeteoSwiss.tcl - MeteoSwiss
# 
# This module implements devices that get weather data from the MeteoSwiss
# via the SwissMetNet data portal
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
# SwissMetNet. For details about the data set, see
# https://opendata.swiss/en/dataset/automatische-wetterstationen-aktuelle-messwerte
# or
# https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell
#
# To get weather data you need first to know the abbreviation of the location
# you are interested in. For this, open data legend file
# https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/info/VQHA80_en.txt
# 
# The weather data is then extracted from the following file that is updated in
# a regular interval :
# https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv
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
#    > thc::DefineDevice Bern,temp \
#    >    -name Bern -group Environment -format "%sC" -range {-30 50} -update 10m \
#    >    -get {thc_MeteoSwiss {"BER" "temperature"}}

######## Virtual device control functions ########

namespace eval ::thc::MeteoSwiss {

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
			set LocationResponse [::thc::GetUrl \
					"https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv"]
			set LocationData [lindex $LocationResponse 2]
		}
			
		# The returned data has the following format:
		# :  Station/Location;Date;tre200s0;rre150z0;sre000z0;gre000z0;ure200s0;tde200s0;dkl010z0;fu3010z0;fu3010z1;prestas0;pp0qffs0;pp0qnhs0;ppz850s0;ppz700s0;dv1towz0;fu3towz0;fu3towz1;ta1tows0;uretows0;tdetows0
		# :  TAE;202010231530;13.50;0.50;0.00;10.00;89.10;11.70;253.00;7.20;15.10;952.50;1015.10;1015.80;-;-;-;-;-;-;-;-
		# :  COM;202010231530;10.40;0.10;0.00;5.00;100.00;10.40;336.00;0.40;1.40;951.30;1019.00;1019.00;-;-;-;-;-;-;-;-
		# :  ABO;202010231530;9.40;0.30;0.00;7.00;96.80;8.90;351.00;2.50;5.40;867.60;-;1017.60;1495.70;-;-;-;-;-;-;-
		# :  AIG;202010231530;13.00;0.80;0.00;7.00;95.00;12.20;343.00;7.90;13.30;971.80;1016.80;1017.00;-;-;-;-;-;-;-;-
		# :  ...

		# Identify the position of the different fields
		catch {
			set Fields [split [lindex \
					[regexp -inline -line {^.*\ytre200s0\y.*$} $LocationData] 0] ";"]
		}
		
	 	# Extract from the data the requested parameters for the different 
	 	# locations
		foreach GetCmd $GetCmdList {
			set Res ""
			catch {
				set Location [lindex $GetCmd 0]
				set Parameter [lindex $GetCmd 1]
				set DataSet [split [lindex \
						[regexp -inline -line "^$Location.*$" $LocationData] 0] ";"]
				set Res [lindex $DataSet \
						[lsearch -exact $Fields $ParameterNames($Parameter)]] 
			}
			lappend Result $Res
		}
		
		return $Result
	}

}; # end namespace thc_MeteoSwiss

return