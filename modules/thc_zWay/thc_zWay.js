/*************************************************************************
* THC - Tight Home Control
**************************************************************************
* thc_zWay.tcl - z-Way extension for THC
* 
* Copyright (C) 2014 Andreas Drollinger
**************************************************************************
* See the file "license.terms" for information on usage and redistribution
* of this file, and for a DISCLAIMER OF ALL WARRANTIES.
*************************************************************************/

// Title: z-Way extension for THC
// The file thc_zWay.js of the module thc_zWay implements some functions for 
// the z-Way server that are used by THC. The defined functions are accessible 
// via the z-Way HTTP interface.
//
// This file is automatically loaded to the z-Way server by the THC module 
// thc_zWay.

var InvalidTimespan={Battery:21600, Multilevel:1800};
var zWayRevision=zway.controller.data.softwareRevisionVersion.value;

/****************************************************\
  Function: Get_Virtual
     Returns the virtual device state
 
  Parameters:
     NI - Virtual device identifier

  Returns:
     Virtual device status
     
  Examples:
     > http://192.168.1.21:8083/JS/Run/Get_Virtual("DummyDevice_bn_5")
     > -> 1
     
  See also:
     <Set_Virtual>
\****************************************************/

Get_Virtual = function(NI) {
	try {
		dev = this.controller.devices.get(NI);
		State = dev.get("metrics:level");

		switch(State) {
			case "on":
				State=1;
				break;
			case "off":
				State=0;
				break;
		}
		
		return ( State );
	}
	catch(err) {}
	return "";
}

/****************************************************\
  Function: Set_Virtual
     Sets the virtual device state
 
  Parameters:
     NI - Virtual device identifier
	  state - New state

  Returns:
     Virtual device status
     
  Examples:
     > http://192.168.1.21:8083/JS/Run/Set_Virtual("DummyDevice_bn_5",1)
     > -> 1
     
  See also:
     <Get_Control>
\****************************************************/

Set_Virtual = function(NI,State) {
	switch(State) {
		case 0:
			State="off";
			break;
		case 1:
			State="on";
			break;
	}

	try {
		dev = this.controller.devices.get(NI);
		dev.set("metrics:level",State)
		return ( Get_Virtual(NI) );}
	catch(err) {}
	return "";
}

/* Get_IndexArray(NI) 
   This function is used by the thc_zWay module to check that this JavaScript
	file is correctly loaded by the z-Way server.
	
   Usage: http://192.168.1.21:8083/JS/Run/Get_IndexArray(8.1)
          -> [8,1,0]
          http://192.168.1.21:8083/JS/Run/Get_IndexArray(7)
          -> [7,0,0]
          http://192.168.1.21:8083/JS/Run/Get_IndexArray("6.1.2")
          -> [6,1,2]
*/
Get_IndexArray = function(NI) {
	var ThreeVal = String(NI).split(".");
	ThreeVal[0]=parseInt(ThreeVal[0]);
	ThreeVal[1]=(ThreeVal.length>1 ? parseInt(ThreeVal[1]) : 0);
	ThreeVal[2]=(ThreeVal.length>2 ? parseInt(ThreeVal[2]) : 0);
  return ThreeVal;
}

/* Sleep(NI,I) 
   Usage: http://192.168.1.21:8083/JS/Run/Sleep([2,5,12,15])
          -> 1
*/
Sleep = function(NI, state) {
	var IndexArray=Get_IndexArray(NI);
	try {
		zway.devices[ IndexArray[0] ].instances[0].Wakeup.Sleep();
		return 1; }
	catch(err) {}
	return "";
};

/* Set_SwitchBinary(NI,I) 
   Usage: http://192.168.1.21:8083/JS/Run/Set_SwitchBinary(7.1, 0)
          -> 0
*/
Set_SwitchBinary = function(NI, state) {
	var IndexArray=Get_IndexArray(NI);
	try {
		zway.devices[ IndexArray[0] ].instances[ IndexArray[1] ].SwitchBinary.Set( state==0?0:255 ); }
	catch(err) {}
	return Get_SwitchBinary(NI);
}

/* Get_SwitchBinary(NI)
   Usage: http://192.168.1.21:8083/JS/Run/Get_SwitchBinary(8.0)
          -> 1
*/
Get_SwitchBinary = function(NI) {
	var IndexArray=Get_IndexArray(NI);
	try {
		return (zway.devices[ IndexArray[0] ].instances[ IndexArray[1] ].SwitchBinary.data.level.value==0) ? 0 : 1; }
	catch(err) {}
	return "";
}

/* Get_SensorBinary(NI)
   Usage : http://192.168.1.21:8083/JS/Run/Get_SensorBinary(2)
           -> 1
*/
Get_SensorBinary = function(NI) {
	var IndexArray=Get_IndexArray(NI);
	try {
		return (zway.devices[ IndexArray[0] ].instances[0].SensorBinary.data[1].level.value==0) ? 1 : 0; }
	catch(err) {
		return ""; }
}

/****************************************************\
  Function: Configure_TagReader
     Configures audible notification for tag reader.
     This function binds the alarm notification to a binary switch Set(1) 
     function which will issue an audible notification on a tag reader each
     time a valid code has been entered.
	  
     Configure_TagReader defines the following bindings (for device 22)
       > http://192.168.1.21:8083/JS/Run/zway.devices[22].Alarm.data[6][5].status.bind( function() {zway.devices[22].SwitchBinary.Set(true); });
       > http://192.168.1.21:8083/JS/Run/zway.devices[22].Alarm.data[6][6].status.bind( function() {zway.devices[22].SwitchBinary.Set(true); });

  Parameters:
     NI - device identifier
     
  Returns:
     -

   Examples:
     > http://192.168.1.21:8083/JS/Run/Configure_TagReader(22)
     > -> null
\****************************************************/

Configure_TagReader = function(NI) {
	var IndexArray=Get_IndexArray(NI);
	if (zWayRevision.substr(0,2)=="v1.") { // z-Way version 1.x
		zway.devices[ IndexArray[0] ].Alarm.data[6][5].status.bind(function() {
			zway.devices[ IndexArray[0] ].SwitchBinary.Set(true); });
		zway.devices[ IndexArray[0] ].Alarm.data[6][6].status.bind(function() {
			zway.devices[ IndexArray[0] ].SwitchBinary.Set(true); });
	} else { // z-Way version 2.x, ...
		zway.devices[ IndexArray[0] ].Alarm.data[6].event.bind(function() {
			zway.devices[ IndexArray[0] ].SwitchBinary.Set(true); });
	}
}

/* Get_TagReader(NI)
   Usage: http://192.168.1.21:8083/JS/Run/Get_TagReader(22)
          -> [1388853574,"lock"]

	z-Way 1.x:
	http://192.168.1.21:8083/ZWaveAPI/Run/devices[22].instances[0].Alarm.data[6][5].status.updateTime
	http://192.168.1.21:8083/ZWaveAPI/Run/devices[22].instances[0].Alarm.data[6][6].status.updateTime
	http://192.168.1.21:8083/ZWaveAPI/Run/devices[22].instances[0].Alarm.data[7][3].status.updateTime
	http://192.168.1.21:8083/ZWaveAPI/Run/devices[22].instances[0].UserCode.data[0].updateTime

	z-Way 2.x:
	http://192.168.1.21:8083/ZWaveAPI/Run/devices[22].instances[0].Alarm.data[6].event.updateTime
	http://192.168.1.21:8083/ZWaveAPI/Run/devices[22].instances[0].Alarm.data[7].event.updateTime
	http://192.168.1.21:8083/ZWaveAPI/Run/devices[22].instances[0].UserCode.data[0].updateTime
*/
Get_TagReader = function(NI) {
	var IndexArray=Get_IndexArray(NI);
	var LastEvent="";
	var LockTime=-1, UnLockTime=-1, TamperTime=-1, WrongCodeTime=-1, MaxTime=-1, WrongCodeValue="";

	if (zWayRevision.substr(0,2)=="v1.") { // z-Way version 1.x
		try {LockTime=      zway.devices[ IndexArray[0] ].instances[0].Alarm.data[6][5].status.updateTime;} catch(err) {}
		try {UnLockTime=    zway.devices[ IndexArray[0] ].instances[0].Alarm.data[6][6].status.updateTime;} catch(err) {}
		try {TamperTime=    zway.devices[ IndexArray[0] ].instances[0].Alarm.data[7][3].status.updateTime;} catch(err) {}
	} else { // z-Way version 2.x, ...
		try {
			if (zway.devices[ IndexArray[0] ].instances[0].Alarm.data[6].event.value==5) {
				LockTime  =zway.devices[ IndexArray[0] ].instances[0].Alarm.data[6].event.updateTime; }
		} catch(err) {}
		try {
			if (zway.devices[ IndexArray[0] ].instances[0].Alarm.data[6].event.value==6) {
				UnLockTime=zway.devices[ IndexArray[0] ].instances[0].Alarm.data[6].event.updateTime; }
		} catch(err) {}
		try {
			if (zway.devices[ IndexArray[0] ].instances[0].Alarm.data[7].event.value==3) {
				TamperTime=zway.devices[ IndexArray[0] ].instances[0].Alarm.data[7].event.updateTime; }
		} catch(err) {}
	}
	try {WrongCodeTime= zway.devices[ IndexArray[0] ].instances[0].UserCode.data[0].updateTime;} catch(err) {}
	try {WrongCodeValue=zway.devices[ IndexArray[0] ].instances[0].UserCode.data[0].code.value;} catch(err) {}

	MaxTime=Math.max(LockTime,UnLockTime,TamperTime,WrongCodeTime,0);
	if(MaxTime==LockTime) {
		return [MaxTime,"lock"]; }
	else if(MaxTime==UnLockTime) {
		return [MaxTime,"unlock"]; }
	else if(MaxTime==TamperTime) {
		return [MaxTime,"tamper"]; }
	else if(MaxTime==WrongCodeTime) {
		return [MaxTime,"wrongcode",WrongCodeValue]; }
	return "";
};

/****************************************************\
  Function: TagReader_LearnLastCode
     Learn the tag reader the last entered code. The tag reader will afterwards 
	  accept the new code as a valid one.
	  
	  The following code learning sequence should be applied :
	  * Using the 'Home' or 'Away' button, enter a new code or use a new 
	    unknown RFID tag.
	  * Run the TagReader_LearnLastCode command. Provide a new UserId (=code
	    storage location).
	  * Wakeup the tag reader. This can happen by entering a valid or invalid 
	    code. The tag reader will receive from the controller the command to 
		 learn the new code.
	  * Try now using the new code or the new RFID tag. The tag reader will 
	    recognize it as valid.
 
  Parameters:
     NI - Device identifier
	  UserId - User identifier (code storage location)

  Returns:
     Information string if the code learning was successful or not
     
  Examples:
     > http://192.168.1.21:8083/JS/Run/TagReader_LearnLastCode(22, 2)
     > -> OK, registered code 52,52,52,52,52,52,0,0,0,0
     
  See also:
     <Configure_TagReader>, <TagReader_ResetCode>
\****************************************************/

// See: http://forum.z-wave.me/viewtopic.php?f=3419&t=20551

TagReader_LearnLastCode = function(NI, UserId) {
	if (typeof UserId=="undefined")
		return "Call: TagReader_LearnLastCode(NI, UserId)";
	var IndexArray=Get_IndexArray(NI);
	var uc = zway.devices[ IndexArray[0] ].UserCode;
	if (uc.data[0] && uc.data[0].hasCode.value) {
		var code = uc.data[0].code.value;
		if (typeof code === "string") {
			uc.Set(UserId, code, 1);
		} else {
			uc.SetRaw(UserId, code, 1); }
		return "OK, registered code "+code;
	} else {
		return "No code could be registered";
	}
}


/****************************************************\
  Function: TagReader_ResetCode
     Reset one or all codes a tag reader knows. If no UserId is defined all
	  codes are reset, otherwise only the code assigned to the UserId.
	  After running this command the tag reader needs to be waked up to receive
	  the command to perform the reset.
 
  Parameters:
     NI - Device identifier
	  UserId - User identifier (code storage location, optional)

  Returns:
     -
     
  Examples:
     > http://192.168.1.21:8083/JS/Run/TagReader_ResetCode(22) -> resets all codes
     > http://192.168.1.21:8083/JS/Run/TagReader_ResetCode(22,3) -> resets the UserId specific code
     
  See also:
     <Configure_TagReader>, <TagReader_LearnLastCode>
\****************************************************/

TagReader_ResetCode = function(NI, UserId) {
	if (typeof NI=="undefined")
		return "Call: TagReader_ResetCode(NI [, UserId])";
	var IndexArray=Get_IndexArray(NI);
	var uc = zway.devices[ IndexArray[0] ].UserCode;
	if (typeof UserId=="undefined")
		uc.Set(0,'',0); // Reset all codes
	else
		uc.Set(UserId,'',0); // Reset the UserId specific code
}

/* Get_Battery(NI)
   Usage: http://192.168.1.21:8083/JS/Run/Get_Battery(22)
          -> 67
*/
Get_Battery = function(NI) {
	var IndexArray=Get_IndexArray(NI);
	var CurrentTime=Math.round(Date.now()/1000);
	try {
		zway.devices[ IndexArray[0] ].instances[0].Battery.Get();
		var UpdateTime=zway.devices[ IndexArray[0] ].instances[0].Battery.data.last.updateTime;
		if (CurrentTime<=UpdateTime+InvalidTimespan["Battery"]) {
			var Level=zway.devices[ IndexArray[0] ].instances[0].Battery.data.last.value;
			return (Level>100?0:Level); } // Empty battery level are reported with 255
		else {
			return ""; }
	}
	catch(err) {
		return ""; }
}

/* Get_SensorMultilevel(NI)
   Usage: http://192.168.1.21:8083/JS/Run/Get_SensorMultilevel("5.0.1")
          -> 77
*/

Get_SensorMultilevel = function(NI) {
	var IndexArray=Get_IndexArray(NI);
	var CurrentTime=Math.round(Date.now()/1000);
	try {
		zway.devices[ IndexArray[0] ].instances[ IndexArray[1] ].SensorMultilevel.Get();
		var UpdateTime=zway.devices[ IndexArray[0] ].instances[ IndexArray[1] ].SensorMultilevel.data[ IndexArray[2] ].val.updateTime;
		if (CurrentTime<=UpdateTime+InvalidTimespan["Multilevel"]) {
			return zway.devices[ IndexArray[0] ].instances[ IndexArray[1] ].SensorMultilevel.data[ IndexArray[2] ].val.value; }
	}
	catch(err) {}
	return "";
}

/****************************************************\
  Function: Get
     Get status from devices
 
  Parameters:
     DeviceList - List of devices organized in an array. Each array element
	               represents a device. A device is itself described by an
						array composed by the zWave command class, and the device 
						identifier. The device identifier is provided by the zWay 
						configuration utility. The identifier is composed by the 
						device number, the instance number, and the data record. 
						All numbers are separated by a dot (.).
     
  Returns:
     Device statuses

   Examples:
     > http://192.168.1.21:8083/JS/Run/Get([["Control","Surveillance"],["SwitchBinary",7.1],["SensorBinary",2],["TagReader",22],["Battery",22],["SensorMultilevel","5.0.1"]])
     > -> [0,0,1,[1407694169,"unlock"],33,17.7]
     > http://192.168.1.21:8083/JS/Run/Get([["Virtual","DummyDevice_bn_5"]])
     > -> [0]
     > http://192.168.1.21:8083/JS/Run/Get([["Control","Surveillance"],["Control","Alarm"],["SwitchBinary",20.1]])
     > -> [0,0,0]
     
  See also:
     <Set>
\****************************************************/

Get = function(DeviceList) {
	var ResultArray=new Array();
	var CurrentTime=Math.round(Date.now()/1000);
	for(var i=0; i<DeviceList.length; i++) {
		var Value="";
		try {
			var Device=DeviceList[i];

			switch(Device[0]) {
				case "Virtual":
					Value=Get_Virtual(Device[1]);
					break;
				case "Control":
					Value=Get_Control(Device[1]);
					break;
				case "SwitchBinary":
					Value=Get_SwitchBinary(Device[1]);
					break;
				case "SensorBinary":
					Value=Get_SensorBinary(Device[1]);
					break;
				case "TagReader":
					Value=Get_TagReader(Device[1]);
					break;
				case "Battery":
					Value=Get_Battery(Device[1]);
					break;
				case "SensorMultilevel":
					Value=Get_SensorMultilevel(Device[1]);
					break;
				default:
					break;
			}
		}
		catch(err) {}
		ResultArray[i]=Value;
	}
	return JSON.stringify(ResultArray); // Stringify, required for z-Way 2.x
}

/****************************************************\
  Function: Set
     Set status for devices
 
  Parameters:
     DeviceList - List of devices organized in an array. Each array element
	               represents a device. A device is itself described by an
						array composed by the zWave command class, and the device 
						identifier. The device identifier is provided by the zWay 
						configuration utility. The identifier is composed by the 
						device number, the instance number, and the data record. 
						All numbers are separated by a dot (.).
     State - Device status, usually 0 or 1
     
  Returns:
     Device state

   Examples:
      > http://192.168.1.21:8083/JS/Run/Set([["Control","Surveillance"]],1)
      > -> [1]
      > http://192.168.1.21:8083/JS/Run/Set([["Virtual","DummyDevice_bn_5"]],1)
      > -> [1]
      > http://192.168.1.21:8083/JS/Run/Set([["SwitchBinary",20.1]],1)
      > -> [1]
     
  See also:
     <Get>
\****************************************************/

Set = function(DeviceList, State) {
	var ResultArray=new Array();
	var CurrentTime=Math.round(Date.now()/1000);
	for(var i=0; i<DeviceList.length; i++) {
		var Value="";
		try {
			var Device=DeviceList[i];

			switch(Device[0]) {
				case "Control":
					Value=Set_Control(Device[1], State);
					break;
				case "Virtual":
					Value=Set_Virtual(Device[1], State);
					break;
				case "SwitchBinary":
					Value=Set_SwitchBinary(Device[1], State);
					break;
				default:
					break;
			}
		}
		catch(err) {}
		ResultArray[i]=Value;
	}
	return JSON.stringify(ResultArray);
}
