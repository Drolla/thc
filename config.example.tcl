### General configuration ###

	# Define the update interval
	thc::DefineHeartBeat 1000 MS; # Update interval in milliseconds. Default is 1000 (ms).

	# Define the log/work directory
	set LogDir "/var/thc"

	# Define the log level and destination
	thc::DefineLog stdout 2

	# Define which state should be backed up and restored after a reboot
	thc::ConfigureRecoveryFile $LogDir/thc_server.state
	thc::DefineRecoveryDeviceStates Surveillance,state

### z-Way configuration ###

	# Initialize the z-Way interface
	thc::zWay::Init "http://localhost:8083"

### Device definitions ###

	thc::DefineDevice Surveillance,state \
				-name Surveillance -group Security -type switch \
				-get {thc_Virtual "Surveillance"} \
				-set {thc_Virtual "Surveillance"}
	thc::DefineDevice Alarm,state \
				-name Alarm -group Security -type switch \
				-get {thc_Virtual "Alarm"} \
				-set {thc_Virtual "Alarm"}
	thc::DefineDevice AllLights,state \
				-name AllLights -group Security -type switch \
				-get {thc_Virtual "AllLights"} \
				-set {thc_Virtual "AllLights"}

	# Register intrusion detection devices
	thc::DefineDevice MotionLiv,state \
				-name MotionLiv -group Security -inverse 1 -sticky 1 \
				-get {thc_zWay "SensorBinary 26"}
	thc::DefineDevice MotionLiv,battery \
				-name MotionLiv -group Battery -format "%s%%" -update 1h \
				-get {thc_zWay "Battery 26"}

	thc::DefineDevice MotionCellar,state \
				-name MotionCellar -group Security -inverse 1 -sticky 1 \
				-get {thc_zWay "SensorBinary 25"}
	thc::DefineDevice MotionCellar,battery \
				-name MotionCellar -group Battery -format "%s%%" -update 1h \
				-get {thc_zWay "Battery 25"}

	# Register light switches
	thc::DefineDevice LightCorridor1st,state \
				-name LightCorridor1st -group Light -type switch \
				-get {thc_zWay "SwitchBinary 7.1"} \
				-set {thc_zWay "SwitchBinary 7.1"}
	thc::DefineDevice LightRoomParent,state \
				-name LightRoomParent -group Light -type switch \
				-get {thc_zWay "SwitchBinary 7.2"} \
				-set {thc_zWay "SwitchBinary 7.2"}
	thc::DefineDevice LightLiv,state \
				-name LightLiv -group Light -type switch \
				-get {thc_zWay "SwitchBinary 8.2"} \
				-set {thc_zWay "SwitchBinary 8.2"}
	thc::DefineDevice LightCorridor,state \
				-name LightCorridor -group Light -type switch \
				-get {thc_zWay "SwitchBinary 20.1"} \
				-set {thc_zWay "SwitchBinary 20.1"}
	thc::DefineDevice Light2nd,state \
				-name Light2nd -group Light -type switch \
				-get {thc_zWay "SwitchBinary 9.0"} \
				-set {thc_zWay "SwitchBinary 9.0" "SwitchBinary 9.1" "SwitchBinary 9.2"}
	thc::DefineDevice LightCellar,state \
				-name LightCellar -group Light -type switch \
				-get {thc_zWay "SwitchBinary 14.1"} \
				-set {thc_zWay "SwitchBinary 14.1"}

	# Register sirens
	thc::DefineDevice Sirene,state \
				-name Sirene -group Misc -type switch \
				-get {thc_zWay "SwitchBinary 16.0"} \
	         -set {thc_zWay "SwitchBinary 16.0"}
	thc::DefineDevice Sirene,battery \
				-name Sirene -group Battery -format "%s%%" -update 1h \
				-get {thc_zWay "Battery 16.0"}

	# Register tag readers
	thc::DefineDevice TagReader1,state \
				-name TagReader1 -group Misc -type switch \
				-get {thc_zWay "TagReader 22"} \
	         -set {thc_zWay "SwitchBinary 22"}
	thc::DefineDevice TagReader1,battery \
				-name TagReader1 -group Battery -format "%s%%" -update 1h \
				-get {thc_zWay "Battery 22"}

	# Register temperature and humidity measurement devices
	thc::DefineDevice MultiParent,temp \
				-name "Temp Room Parent" -group Environment -format "%s°C" -range {10 30} -update 1m \
				-get {thc_zWay "SensorMultilevel 5.0.1"} -gexpr {$Value-1.5}
	thc::DefineDevice MultiParent,battery \
				-name "Bat MultiParent" -group Battery -format "%s%%" -update 1h \
				-get {thc_zWay "Battery 5"}

	thc::DefineDevice MultiLiv,temp \
				-name "Temp Liv" -group Environment -format "%s°C" -range {10 25} -update 1m \
				-get {thc_zWay "SensorMultilevel 11.0.1"}
	thc::DefineDevice MultiLiv,hum \
				-name "Humidity Liv" -group Environment -format "%s%%" -range {20 100} -update 1m \
				-get {thc_zWay "SensorMultilevel 11.0.5"}
	thc::DefineDevice MultiLiv,battery \
				-name MultiLiv -group Battery -format "%s%%" -update 1h \
				-get {thc_zWay "Battery 11"}

	thc::DefineDevice MultiCellar,temp \
				-name "Temp Cellar" -group Environment -format "%s°C" -range {10 25} -update 1m \
				-get {thc_zWay "SensorMultilevel 10.0.1"}
	thc::DefineDevice MultiCellar,hum \
				-name "Humidity Cellar" -group Environment -format "%s%%" -range {20 100} -update 1m \
				-get {thc_zWay "SensorMultilevel 10.0.5"}
	thc::DefineDevice MultiCellar,battery \
				-name MultiCellar -group Battery -format "%s%%" -update 1h \
				-get {thc_zWay "Battery 10"}

	# OpenWeatherMap devices
	# thc::DefineDevice ChauxDeFonds,chx_temp \
	# 			-name "Temp Chaux-de-Fonds" -group Environment -format "%s°C" -update 5m \
	# 			-get {thc_OpenWeatherMap {"La Chaux-de-Fonds,ch" "temp"}}
	# thc::DefineDevice ChauxDeFonds,chx_hum \
	# 			-name "Humidity Chaux-de-Fonds" -group Environment -format "%s%%" -update 5m \
	# 			-get {thc_OpenWeatherMap {"La Chaux-de-Fonds,ch" "humidity"}}

	# MeteoSwiss devices
	thc::DefineDevice ChauxDeFonds,chx_temp \
				-name "Temp Chaux-de-Fonds" -group Environment -format "%s°C" -update 10m \
				-get {thc_MeteoSwiss {"CDF" "temperature"}}
	thc::DefineDevice ChauxDeFonds,chx_hum \
				-name "Humidity Chaux-de-Fonds" -group Environment -format "%s%%" -update 10m \
				-get {thc_MeteoSwiss {"CDF" "humidity"}}

	set SensorDeviceList {MotionLiv,state MotionCellar,state}; #WindowCellar
	set SireneDeviceList {Sirene,state}
	set TagReaderList {TagReader1,state}

### Random light activity ###

	# Specify which light should be randomly switched on and of in
	# surveillance state
	
	namespace eval thc::RandomLight {
		# Define the location and time zone (e.g. Chaux-de-Fonds)
		Configure -longitude 6.8250 -latitude 47.1013 -zone "auto"

		# Define the lights that should be randomly controlled in surveillance mode
		Define LightLiv,state         -time {7.2 $SunriseT-0.3 $SunsetT+0.0 21.5} -min_interval 0.30 -probability_on 0.2
		Define LightRoomParent,state  -time {6.7 $SunriseT-0.0 $SunsetT+0.2 23.0} -min_interval 0.30 -probability_on 0.7 -default 1
		Define LightCorridor,state    -time {7.0 $SunriseT-0.2 $SunsetT+0.3 22.0} -min_interval 0.30 -probability_on 0.4
		Define LightCorridor1st,state -time {6.5 $SunriseT-0.1 $SunsetT+0.4 22.5} -min_interval 0.30 -probability_on 0.8
		Define Light2nd,state         -time {6.4 $SunriseT-0.1 $SunsetT+0.2 22.1} -min_interval 0.30 -probability_on 0.4
		#Define LightCellar,state        -time {7.2 $SunriseT-0.3 $SunsetT+0.0 21.5} -min_interval 0.30 -probability_on 0.0
	}

### Mail setup ###

	thc::MailAlert::Configure -method custom -custom_command mail_custom_send

	proc mail_custom_send {Title Message RecipientList From} {
		# Backslash double quotes
		regsub -all "\"" $Message "\\\"" Message
		regsub -all "\"" $Title "\\\"" Title
	
		# Call the Unix mail command to send the message
		exec bash -c "echo \"$Message\" | mail -s \"$Title\" -r $From $RecipientList"
	}

### CsvLog ###

	# Specify the CSV data file
	set CsvFile "$LogDir/thc.csv"

	# Create/open the CSV file
	thc::Csv::Open -file $CsvFile -min_interval 300; # 5 minutes interval

### RRD ###

	# Specify the RRD database file
	set RrdFile "$LogDir/thc.rrd"

	# Create/open the RRD file, create databases for 26h, 33d and 358d, using 
	# respectively an update interval of 1', 5' and 60'.
	thc::Rrd::Open -file $RrdFile -step 60 \
		-rra [list 1 [expr 26*60]] \
		-rra [list 5 [expr 33*24*12]] \
		-rra [list 60 [expr 358*24]]

	# Make a copy of the generated graph files
	proc CopyGraphs {DayTime} {
		set Date [clock format $DayTime -format %Y%m%d]
		foreach Pic {thc thc_bat thc_mlt thc_rad} {
			file copy -force $::LogDir/$Pic.png $::LogDir/${Pic}_${Date}.png
		}

		set Date [clock format $DayTime -format %Y%m]
		foreach Pic {thc_32d thc_bat_32d thc_mlt_32d thc_rad_32d} {
			file copy -force $::LogDir/$Pic.png $::LogDir/${Pic}_${Date}.png
		}
	}

	# Graph generation procedure. The following time spans are accepted: 1d, 8d, 32d.
	proc GenerateGraphs {GraphSpan} {
		upvar #0 thc::DeviceList DeviceList
		upvar #0 thc::Time Time


		# Define the RRD graph grid and time span in function of the provided 
		# argument:
		switch -- $GraphSpan {
			1d {
				set PngFileEnding ".png"
				set RrdArguments {
					--x-grid MINUTE:10:HOUR:1:HOUR:3:0:%b%d,%Hh \
					--start end-26h --step 60 --height 300 --width 1560}
			}
			8d {
				set PngFileEnding "_8d.png"
				set RrdArguments {
					--x-grid HOUR:2:HOUR:12:DAY:1:0:%b%d,%Hh \
					--start end-8d --step 600 --height 300 --width 1152}
			}
			32d {
				set PngFileEnding "_32d.png"
				set RrdArguments {
					--x-grid HOUR:6:DAY:1:DAY:5:0:%b%d,%Hh \
					--start end-32d --step 1800 --height 300 --width 1536}
			}
		}

		# Generate separate graphs for the 1) binary devices, 2) battery levels, 
		# 3) temperature and humidity measurement devices.
		thc::Rrd::Graph \
			-file $::LogDir/thc$PngFileEnding \
			-type binary \
			-rrd_arguments [list \
				--title "Fusion 18 Light, Surveillance and Alarm Activities - [clock format $Time -format {%A, %Y.%m.%d, %H:%M:%S}]" \
				--vertical-label " " \
				--height 300 --alt-autoscale --end $Time {*}$RrdArguments] \
			Surveillance,state Alarm,state AllLights,state \
			{*}[lsearch -all -inline $DeviceList Motion*,state] {*}[lsearch -all -inline $DeviceList Window*,state] \
			{*}[lsearch -all -inline $DeviceList Light*,state]

		thc::Rrd::Graph \
			-file $::LogDir/thc_bat$PngFileEnding \
			-type analog \
			-rrd_arguments [list \
				--title "Fusion 18 Battery level - [clock format $Time -format {%A, %Y.%m.%d, %H:%M:%S}]" \
				--vertical-label "Battery level (%)" \
				--height 300 --alt-autoscale --end $Time {*}$RrdArguments] \
			{*}[lsearch -all -inline $DeviceList *,battery]

		thc::Rrd::Graph \
			-file $::LogDir/thc_mlt$PngFileEnding \
			-type analog \
			-rrd_arguments [list \
				--title "Fusion 18 Temperature and Humidity - [clock format $Time -format {%A, %Y.%m.%d, %H:%M:%S}]" \
				--vertical-label "Temperature (C)" --right-axis-label "Humidity (%)" \
				--right-axis 5:-35 \
				--height 300 --alt-autoscale --end $Time {*}$RrdArguments] \
			{*}[lsearch -all -inline $DeviceList *,temp] {MultiCellar,hum ",35,+,5,/"} {MultiLiv,hum ",35,+,5,/"}

		thc::Rrd::Graph \
			-file $::LogDir/thc_chx$PngFileEnding \
			-type analog \
			-rrd_arguments [list \
				--title "Chaux-de-Fonds Temperature and Humidity - [clock format $Time -format {%A, %Y.%m.%d, %H:%M:%S}]" \
				--vertical-label "Temperature (C)" --right-axis-label "Humidity (%)" \
				--right-axis 5:-35 \
				--height 300 --alt-autoscale --end $Time {*}$RrdArguments] \
			{ChauxDeFonds,chx_temp} {ChauxDeFonds,chx_hum ",35,+,5,/"}
		}

### HTTP debug server listening port ###

	thc::HttpDServer::Start 8085

	foreach {PlotSpan FileEnding} {1day "" 8day "_8d" 32day "_32d"} {
		thc::DefineDevice Security,$PlotSpan \
					-type image -data $::LogDir/thc$FileEnding.png \
					-name Security -group "Graphs $PlotSpan"
	
		thc::DefineDevice Environment,$PlotSpan \
					-type image -data $::LogDir/thc_mlt$FileEnding.png \
					-name Environment -group "Graphs $PlotSpan"

		thc::DefineDevice ChauxDeFonds,$PlotSpan \
					-type image -data $::LogDir/thc_chx$FileEnding.png \
					-name "Chaux-de-Fonds" -group "Graphs $PlotSpan"
					
		thc::DefineDevice Battery,$PlotSpan \
					-type image -data $::LogDir/thc_bat$FileEnding.png \
					-name Battery -group "Graphs $PlotSpan"
	}
	
	thc::DefineDevice zWay,Links \
				-type link -data http://192.168.1.21:8083
	thc::DefineDevice thc_Timer,Links \
				-type module -data thc_Timer

### HTTP web server ###

	thc::Web::Start 8086

### Task and rules ###

	###### Permanent jobs ######

	# Evaluate every 24 hours the sun rise and sun set time
	thc::DefineJob -tag EvalSun -time 01h -repeat 24h -init_time +0 -description "Evaluate the sun shine time" {
		thc::RandomLight::EvaluateSunRiseSunSet
	}

	# Generate every 5 minutes the 1-day graphs
	thc::DefineJob -tag RrdGph1D -time +5m -repeat 5m -description "1 day graph generation" {
		GenerateGraphs 1d
	}

	# Generate all hours the 1-week graphs
	thc::DefineJob -tag RrdGph1W -time +1h -repeat 1h -description "1 week graph generation" {
		GenerateGraphs 8d
	}

	# Generate all days the 1 month graph
	thc::DefineJob -tag RrdGph1M -time 01h05m -repeat 24h -description "1 month graph generation" {
		GenerateGraphs 32d
		CopyGraphs [expr {$Time-2*3600}]; # Use as date the day before
	}

	# Log the device states all minutes into the RRD databases
	thc::DefineJob -tag RrdLog -time +1m -repeat 1m -description "RRD log" {
		thc::Rrd::Log
		thc::Csv::Log
		thc::ResetStickyStates
	}

	###### Permanent surveillance and control tasks ######

	set AlarmSireneOffT 3m; # Defines how long the sirens have to run after an intrusion
	set AlarmLightOffT 45m; # Defines how long the lights should be switched on after an intrusion
	set AlarmRetriggerT 5m; # Defines minimum alarm retrigger interval
	set AlertMailRetriggerT 45m

	
	# Check if any of the specified intrusion detection devices detected an activity:
	proc GetSensorEvent {} {
		global SensorDeviceList
		foreach Sensor $SensorDeviceList {
			if {$thc::Event($Sensor)==1} {
				return 1 } }
		return 0
	}

	proc GetTagReaderEvents {} {
		global TagReaderList
		set TagReaderEvents {}
		foreach TagReader $TagReaderList {
			if {$thc::Event($TagReader)!=""} {
				lappend TagReaderEvents [lrange $thc::Event($TagReader) 1 end]} }
		return $TagReaderEvents
	}

	# Tag reader input handling
	thc::DefineJob -tag TRCheck -description "Tag Reader Check" -repeat 0 {
		foreach TagReaderEvent [GetTagReaderEvents] {
			thc::Log "Tag reader event: $TagReaderEvent"
			switch -exact -- [lindex $TagReaderEvent 0] {
				"tamper" {}
				"lock" {
					# Set the surveillance device state, this will enable the 
					# surveillance mode (the next heartbeat)
					thc::Set {Surveillance,state} 1 }
				"unlock" {
					# Disable the surveillance device state, this will disable 
					# the surveillance mode (the next heartbeat)
					thc::Set {Surveillance,state} 0 }
				"wrongcode" {
					# If the surveillance mode is not use active, accept 
					# codes '1111' and '2222' to respectively enable and 
					# disable all lights.
					if {$State(Surveillance,state)==0} {
						switch -- [lindex $TagReaderEvent 1] {
							"1111"  { thc::Set {AllLights,state} 1 }
							"2222"  { thc::Set {AllLights,state} 0 } 
							default { thc::Log "Tag reader: Wrong code entered: [lindex $TagReaderEvent 1]" }
						}
					}
				}
			}
		}
	}

	# Surveillance enabling
	thc::DefineJob -tag SurvEn -description "Surveillance enabling" -repeat 0 \
	               -condition {$thc::Event(Surveillance,state)==1} {
		thc::Log "Enabling surveillance"
		thc::RandomLight::Control 0
		thc::Set Alarm,state 0

		thc::DefineJob -tag RdmLight -time +5s -repeat 1m -description "Random light activity" \
		               -condition {$thc::State(Alarm,state)!=1} {
			thc::RandomLight::Control
		}

		# Intrusion detection
		thc::DefineJob -tag Intrusion -description "Intrusion detection" \
		          -repeat 0 -min_interval $AlarmRetriggerT \
					 -condition {[GetSensorEvent]} {

		 	# An intrusion has been detected: Enable the sirens, and run new jobs 
			# to send alert mails/SMS
			thc::Log "Alarm on"
			thc::Set Alarm,state 1
			thc::Set $SireneDeviceList 1
			thc::RandomLight::Control 1
			
			thc::DefineJob -tag AlrtMail -description "Send alert mail" -min_interval $AlertMailRetriggerT -time +2s {
				thc::MailAlert::Send \
					-to abcd@abcd.ch \
					-from efgh@efgh.ch \
					-title "Alarm Alert" \
					"Sensor triggered"
					thc::Log "Alarm mail alerts sent"
			}
	
			thc::DefineJob -tag SirenOff -description "Stop the alarm siren" -time +$AlarmSireneOffT {
				thc::Set $SireneDeviceList 0
				thc::Log "Alarm siren stopped"
			}
	
			thc::DefineJob -tag LightOff -description "Switch off the alarm lights" -time +$AlarmLightOffT {
				thc::RandomLight::Control 0
				thc::Set Alarm,state 0
				thc::Log "Alarm lights turned off"
			}
		}
	}

	# Surveillance disabling
	thc::DefineJob -tag SurvDis -description "Surveillance disabling" -repeat 0 \
	          -condition {$thc::Event(Surveillance,state)==0} {
		thc::Log "Disabling surveillance"
		thc::Set $SireneDeviceList 0
		thc::RandomLight::Control 0
		thc::Set Alarm,state 0
		thc::KillJob RdmLight Intrusion AlrtMail SirenOff LightOff
	}

	# All light control
	thc::DefineJob -tag AllLight -description "All light control" -repeat 0 \
	          -condition {$thc::Event(AllLights,state)==0 || $thc::Event(AllLights,state)==1} {
		thc::Log "All Lights"
		thc::Set $SireneDeviceList 0
		thc::RandomLight::Control $State(AllLights,state)
	}
