/**********************************************************************
* THC - Tight Home Control
**************************************************************************
* thc_Web.js - THC client side web framework based on JQuery Mobile
*
* Copyright (C) 2015/2016 Andreas Drollinger
**************************************************************************
* See the file "LICENSE" for information on usage and redistribution
* of this file, and for a DISCLAIMER OF ALL WARRANTIES.
*************************************************************************/


/***************************** Global variables *****************************/

	// Child ID vs Device ID lookup table. The child ID corresponds to the 
	// device ID but replaces dots (.) and commas (,) by underscores (_).
	var ChildId2DeviceId={};
	
	// Device info lookup table that is provided by the /api/GetDeviceInfo 
	// command of the HTTP server.
	var DevicesInfo={};

	// Device state lookup table that is provided by the /api/GetDeviceStates 
	// command of the HTTP server.
	var DeviceStates={};
	
	// Device updates are stalled during one update iteration if the device 
	// state has been changed via this JQMobile GUI. This avoids that the 
	// displayed device state is set back to the previous state until THC 
	// provides to the JQMobile GUI the updated value.
	var StallDeviceUpdates={};
	
	// Support of 2 display types that change slightly some GUI dimensions:
	var DisplayType="Classic"; // 'Classic' or 'Mobile'
	
	// Selected JQuery Mobile Theme
	var Theme="a";

	// Grid or non-grid display mode
	var Grid=true;

	// Device Widget objects: Each device type has an element that is 
	// itself an object with its methods. At least 'Create' and 'Update' are
	// present as method.
	// DeviceWidget = {
	//    switch: {Update: function() {...}, Create: function() {...}},
	//    level: {Update: function() {...}, Create: function() {...}},
	//    ...
	// }
	// The available widget objects are defined in the second part in this file.
	var DeviceWidget={};


/***************************** Device status updates **************************/

	// UpdateStates updates the device status with provided states
	function UpdateStates(NewDeviceStates) {
		DeviceStates=NewDeviceStates;
		$.each(NewDeviceStates, function(DeviceId, DeviceValue) {
			var ChildId = DeviceId.replace(/[.,]/g,"_");
			var DeviceType = DevicesInfo[DeviceId]["type"];
			if (!StallDeviceUpdates[DeviceId]) {
				DeviceWidget[ DeviceType ].Update(ChildId,DeviceId,DeviceValue); }
			StallDeviceUpdates[DeviceId]=false;
		});
	}
	
	// UpdateForever updates in an infinite loop the device states
	function UpdateForever() {
		setInterval(function() {
			$.ajax({
				url: "/api/GetDeviceStates",
				success: function(data) {UpdateStates(data);},
				dataType: "json"});
		}, 2000);
	}
	
/***************************** GUI creation and theme handling **************************/
	
	// BuildGui generates the entire GUI for the current device configuration.
	function BuildGui() {
		// Append a new page onto the end of the body. Add for the page a header 
		// and footer.
		$('#page_body').append(
			'<div data-role="page" id="page_main" data-theme="'+Theme+'" data-content-theme="'+Theme+'">' +
				'<div data-role="header" data-position="fixed">' +
					'<h1>Tight Home Control</h1>' +
					'<a href="#CfgPopupMenu" data-rel="popup" data-transition="slideup">Cfg</a>' +
					'<div data-role="popup" id="CfgPopupMenu">' +
						'<ul data-role="listview" data-inset="true">' +
							'<li data-role="list-divider">Configurations</li>' +
							'<li><a data-role="button" onclick="ThemeSwitch()">Color</a></li>' +
							'<li><a data-role="button" onclick="GridSwitch()">Grid</a></li>' +
						'</ul>' +
					'</div>' +
				'</div>' +
				'<div data-role="content" id="page_main_content">' +
				'</div>' +
				'<div data-role="footer" data-position="fixed">' +
					'<h1>Tight Home Control</h1>' +
				'</div>' +
			'</div>');
	
		// Extract the different device groups and initiate the device update
		// stalling table.
		var Groups=[];
		$.each(DevicesInfo, function(DeviceId, DeviceInfo) {
			if (Groups.indexOf(DeviceInfo["group"])==-1) {
				Groups[Groups.length]=DeviceInfo["group"]; }
			StallDeviceUpdates[DeviceId]=false;
		});
	
		// Generate the groups and within each group the devices. Depending the 
		// grid configuration the generated HTML code is slightly different.
		$.each(Groups, function(GroupNbr, Group) {
			if (Grid)
				var GroupContent='<div class="ui-grid-d my-breakpoint" id="group-content-'+GroupNbr+'"></div>';
			else
				var GroupContent='<ul data-role="listview" data-inset="true" id="group-content-'+GroupNbr+'"></ul>';
			$('#page_main_content').append(
				'<div data-role="collapsible" id="group-'+GroupNbr+'">' +
					'<h4>'+Group+'</h4>' +
					GroupContent +
				'</div>');
	
			$.each(DevicesInfo, function(DeviceId, DeviceInfo) {
				if (DeviceInfo["group"]!=Group) {
					return 0; // breaks the inner loop
				}
				
				var ChildId = DeviceId.replace(/[.,]/g,"_");
				ChildId2DeviceId[ChildId] = DeviceId;
				var DeviceType = DeviceInfo["type"];
				if (Grid)
					$("#group-content-"+GroupNbr).append( '<div class="ui-block-'+'abcde'[4]+' device_outcontainer"><div class="ui-bar ui-bar-'+Theme+' device_container" id="cont-'+ChildId+'"></div></div>' );
				else
					$("#group-content-"+GroupNbr).append( '<li class="ui-field-contain" id="cont-'+ChildId+'"></li>' );
				DeviceWidget[DeviceType].Create( "#cont-"+ChildId, ChildId, DeviceId, DeviceInfo);
			});
		});
	
		// Initialize the new page 
		$.mobile.initializePage();
	
		// Navigate to the new page
		$.mobile.changePage("#page_main", "pop", false, true);
		
		// Apply the right device widget sizes
		ResizeGui();
	}
	
	// Once the document is ready (loaded), evaluate the display type, load the
	// device information, build the device depending GUI, and go into the 
	// infinite device status update loop
	$(document).ready(function() {
		if ( /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(navigator.userAgent.toLowerCase()) ) {
			DisplayType="Mobile";
		}
	
		$.getJSON('/api/GetDeviceInfo', function(data) {
			DevicesInfo=data;
			BuildGui();
			UpdateForever();
		});
	});
	
	// Handle a resizing of the window
	$(window).resize(function() {
		ResizeGui();
	});
	
	// ResizeGui sizes the device widgets in function of the display width and
	// the display type (mobile vs desktop)
	function ResizeGui() {
		var width=$(window).width();
		var MinWidth=(DisplayType=="Mobile" ? 180 : 200);
		var NbrCols=(Grid ? Math.floor(width/MinWidth) : 1);
		$(".device_outcontainer").css({'width':(100/NbrCols)+'%'});
	}
	
	// SelectorExists checks if a CSS selector is defined.
	function SelectorExists(Selector) {
	    for (var SsIdx = 0; SsIdx < document.styleSheets.length; SsIdx++) {
			var styleSheet = document.styleSheets[SsIdx];
			var cssRules = styleSheet.rules ? styleSheet.rules : styleSheet.cssRules;
			for (var RIdx = 0; RIdx < cssRules.length; ++RIdx) {
				if(cssRules[RIdx].selectorText == Selector) return true;
			}
		}
		return false;
	}
	
	// ThemeSwitch selects the next available theme defined by the jQuery mobile
	// theme CSS file. A wrap around to the first theme is implemented if the 
	// last theme was selected. The GUI is refreshed after the theme change.
	function ThemeSwitch() {
		Theme = String.fromCharCode(Theme.charCodeAt(0) + 1);
		if (!SelectorExists(".ui-body-"+Theme))
			Theme="a";
		RebuildGui();
		return;
	}
	
	// GridSwitch toggles the grid configuration. The GUI is refreshed after the 
	// grid change.
	function GridSwitch() {
		Grid=!Grid;
		RebuildGui();
	}
	
	// RebuildGui rebuilds the GUI. It removes first the defined pages and 
	// generates then them again.
	function RebuildGui() {
		$('div[data-role="page"]').remove();
		BuildGui();
	}
	
	// GetStyleSheets returns an array of the loaded CSS style sheets. This function
	// can be used by a slave window script to get the list of base CSS file.
	function GetStyleSheets() {
		var StyleSheetObjs=document.styleSheets;
		var StyleSheets=[];
		for (var i=0; i<StyleSheetObjs.length; i++) {
			var StyleSheet=StyleSheetObjs[i].href; // http://localhost:8086/www_jqmobile/thc_jqmobile_blue.min.css
			// StyleSheet=StyleSheet.replace(/^\s*http:\/\//,"").replace(/^.*?\//,""); // www_jqmobile/thc_jqmobile_blue.min.css
			StyleSheet=StyleSheet.replace(document.baseURI,""); // thc_jqmobile_blue.min.css
			StyleSheets.push(StyleSheet);
		}
		return StyleSheets;
	}
	
	// GetTheme returns the currently selected CSS theme. This function can be 
	// used by a slave window script to get the the theme of the parent window.
	function GetTheme() {
		return Theme;
	}
	
/***************************** Device Widgets **************************/

// Predefined device widgets. The object DeviceWidget gets for each device type
// an element that is itself an object with various methods. The methods 
// 'Update' and 'Create' are mandatory methods, but depending of the widget 
// type additional methods may be added.


/**** Default ****/

	DeviceWidget[""]={};
	
	DeviceWidget[""].Update = function(ChildId, DeviceId, Value) {
		$("#"+ChildId).text(Value);
	}
	
	DeviceWidget[""].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<label id="' + ChildId + '" class="label-value" style="font-weight: 700;">?</label>');
	}
	
/**** Link ****/

	DeviceWidget["link"]={};

	DeviceWidget["link"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<a href="' + DeviceInfo["data"] + '" target="_blank">Open</a>');
	}

/**** Module ****/

	DeviceWidget["module"]={};

	DeviceWidget["module"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<a href="module/'+DeviceInfo["data"]+'/index.html" target="_blank">Open</a>');
	}

/**** Image ****/

	DeviceWidget["image"]={};

	DeviceWidget["image"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<a href="#page_' + ChildId + '">Open</a>');

		$('#page_body').append(
			'<div data-role="page" id="page_' + ChildId + '" data-theme="'+Theme+'" data-content-theme="'+Theme+'">' +
				'<div data-role="header" data-position="fixed">' +
					'<h1>Tight Home Control</h1>' +
					'<a href="#page_main" data-rel="back">Back</a>' +
				'</div>' +
				'<div style="overflow: auto">' +
					'<img style="display:none" id="img_' + ChildId + '"/>' +
				'</div>' +
				'<div data-role="footer">' +
					'<h1>Tight Home Control</h1>' +
				'</div>' +
			'</div>');

		$(document).on("pagebeforeshow","#page_" + ChildId, function(event, data){
			var ChildId = this.id.replace("page_", "");
			var DeviceId = ChildId2DeviceId[ChildId];
			var ImagePath = "/api/GetDeviceData "+DeviceId;
			$("#img_" + ChildId).attr("src", ImagePath);
			$("#img_" + ChildId).show();
		});
}

/**** Switch ****/

	DeviceWidget["switch"]={};

	DeviceWidget["switch"].Update=function(ChildId, DeviceId, Value) {
		var CurrentValue = $("#"+ChildId).val();
		Value = (Value=="1" || Value=="true" ? 1 : 0);
		if (Value==CurrentValue)
			return;
		$("#"+ChildId).val(Value).slider('refresh');
	}
	
	DeviceWidget["switch"].ChangeState=function(ChildId,DeviceId) {
		var CurrentValue = $("#"+ChildId).val();
		//this.Update(ChildId,DeviceId,CurrentValue);
		//DeviceStates[DeviceId]=CurrentValue;
		StallDeviceUpdates[DeviceId]=true;
		$.get("/api/SetDeviceState "+DeviceId+" "+CurrentValue);
	}
	
	DeviceWidget["switch"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<select id="' + ChildId + '" data-role="slider">' +
				'<option value="0">Off</option>' +
				'<option value="1">On</option>' +
			'</select>');

		$("#"+ChildId).on('slidestop', function( event ) {
			DeviceWidget["switch"].ChangeState(ChildId,DeviceId);
		});
	}

/**** Level ****/

	DeviceWidget["level"]={};

	DeviceWidget["level"].Update=function(ChildId, DeviceId, Value) {
		if ($("#"+ChildId).val()!=Value) {
			$("#"+ChildId).val(Value);
			$("#"+ChildId).slider('refresh');
		}
	}
	
	DeviceWidget["level"].ChangeState=function(ChildId, DeviceId) {
		StallDeviceUpdates[DeviceId]=true;
		$.get("/api/SetDeviceState "+DeviceId+" "+ $("#"+ChildId).val() );
	}
	
	DeviceWidget["level"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		var Range = (DevicesInfo[DeviceId]["range"].length==0 ? [0,1] : DevicesInfo[DeviceId]["range"]);
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<input data-type="range" id="' + ChildId + '" value="'+Range[0]+'" min="'+Range[0]+'" max="'+Range[1]+'" step="'+(Range[1]-Range[0])/100+'" data-highlight="true">');

		$(Parent).on("slidestop", "#"+ChildId, function(event) {
			DeviceWidget["level"].ChangeState(ChildId,DeviceId);
		});
	}
	