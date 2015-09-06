/*************************************************************************
* THC - Tight Home Control
**************************************************************************
* thc_Web.js - THC client side web framework based on JQuery Mobile
*
* Copyright (C) 2015 Andreas Drollinger
**************************************************************************
* See the file "LICENSE" for information on usage and redistribution
* of this file, and for a DISCLAIMER OF ALL WARRANTIES.
*************************************************************************/

var ChildId2DeviceId={};
var DevicesInfo={};
var DeviceStates={};
var StallDeviceUpdates={};
var DisplayType="Classic";
var ColorMode=0;

var DeviceGui={};

function UpdateStates(NewDeviceStates) {
	DeviceStates=NewDeviceStates;
	$.each(NewDeviceStates, function(DeviceId, DeviceValue) {
		var ChildId = DeviceId.replace(/[.,]/g,"_");
		var DeviceType = DevicesInfo[DeviceId]["type"];
		if (!StallDeviceUpdates[DeviceId]) {
			DeviceGui[ DeviceType ].Update(ChildId,DeviceId,DeviceValue); }
		StallDeviceUpdates[DeviceId]=false;
	});
}

function UpdateForever() {
	setInterval(function() {UpdateNow()}, 2000);
}

var NbrUpdates=0;
function UpdateNow() {
	//$(".title-text").text(NbrUpdates++);
	$.ajax({
		url: "/api/GetDeviceStates",
		success: function(data) {
			UpdateStates(data);
		},
		dataType: "json"});
}

function ViewSwitch() {
	if (DisplayType=="Mobile") {
		DisplayType="Classic";
		$('link[href="thc_Web_mobile.css"]').attr({href : "thc_Web.css"});
	} else {
		DisplayType="Mobile";
		$('link[href="thc_Web.css"]').attr({href : "thc_Web_mobile.css"});
	}
	ResizeGui();
}

function ColorSwitch() {
	switch( (++ColorMode)%2 ) {
		case 0:
			$('link[href="thc_Web_ColorBlue.css"]').attr({href : "thc_Web_ColorDarkGray.css"});
			break;
		case 1:
			$('link[href="thc_Web_ColorDarkGray.css"]').attr({href : "thc_Web_ColorBlue.css"});
			break;
	}
}

function ShowHideToggle(Element) {
   $(Element).toggle(500);
}

function BuildGui() {
	// Append the new page onto the end of the body
	$('#page_body').append(
		'<div data-role="page" id="page_main" data-theme="a">' +
			'<div data-role="header">' +
				'<h1>Tight Home Control</h1>' +
			'</div>' +
			'<div data-role="content" id="page_main_content">' +
			'</div>' +
			'<div data-role="footer">' +
				'<h1>Tight Home Control</h1>' +
			'</div>' +
		'</div>');

	var Groups=[];
	$.each(DevicesInfo, function(DeviceId, DeviceInfo) {
		if (Groups.indexOf(DeviceInfo["group"])==-1) {
			Groups[Groups.length]=DeviceInfo["group"]; }
		StallDeviceUpdates[DeviceId]=false;
	});

	$.each(Groups, function(GroupNbr, Group) {
		$('#page_main_content').append(
			'<div data-role="collapsible" id="group-'+GroupNbr+'">' +
				'<h4>'+Group+'</h4>' +
				'<ul data-role="listview" data-inset="true" id="group-content-'+GroupNbr+'">' +
				'</ul>' +
			'</div>');

		$.each(DevicesInfo, function(DeviceId, DeviceInfo) {
			if (DeviceInfo["group"]!=Group) {
				return 0; // breaks the inner loop
			}
			
			var ChildId = DeviceId.replace(/[.,]/g,"_");
			ChildId2DeviceId[ChildId] = DeviceId;
			var DeviceType = DeviceInfo["type"];
			$("#group-content-"+GroupNbr).append( '<li class="ui-field-contain" id="cont-'+ChildId+'"></li>' );
			DeviceGui[DeviceType].Create( "#cont-"+ChildId, ChildId, DeviceId, DeviceInfo);
		});
	});

	// Initialize the new page 
	$.mobile.initializePage();

	// Navigate to the new page
	$.mobile.changePage("#page_main", "pop", false, true);
}

function ResizeGui() {
	var width=$(window).width();
	var MinWidth=(DisplayType=="Mobile" ? 700 : 250);
	if (width<2*MinWidth) {
		$(".item-outsidecontainer").css({'width':'100%'});
	} else if (width<3*MinWidth) {
		$(".item-outsidecontainer").css({'width':'50%'});
	} else if (width<4*MinWidth) {
		$(".item-outsidecontainer").css({'width':'33.333%'});
	} else {
		$(".item-outsidecontainer").css({'width':'25%'});
	}
}

function getPPI(){
	// create an empty element
	var div = document.createElement("div");
	// give it an absolute size of one inch
	div.style.width="1in";
	// append it to the body
	var body = document.getElementsByTagName("body")[0];
	body.appendChild(div);
	// read the computed width
	var ppi = document.defaultView.getComputedStyle(div, null).getPropertyValue('width');
	// remove it again
	body.removeChild(div);
	// and return the value
	return parseFloat(ppi);
}

$(document).ready(function() {
	$.getJSON('/api/GetDeviceInfo', function(data) {
		DevicesInfo=data;
		BuildGui();
		UpdateForever();
	});
});

$(window).resize(function() {
	ResizeGui();
});

/******************************** Device GUIs **************************/


/**** Default ****/

	DeviceGui[""]={};
	
	DeviceGui[""].Update = function(ChildId, DeviceId, Value) {
		$("#"+ChildId).text(Value);
	}
	
	DeviceGui[""].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<label id="' + ChildId + '">?</label>');
	}
	
/**** Link ****/

	DeviceGui["link"]={};

	DeviceGui["link"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<a class="ui-btn" href="' + DeviceInfo["data"] + '" target="_blank">Open</a>');
	}

/**** Module ****/

	DeviceGui["module"]={};

	DeviceGui["module"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<a class="ui-btn" href="module/'+DeviceInfo["data"]+'/index.html" target="_blank">Open</a>');
	}

/**** Image ****/

	DeviceGui["image"]={};

	DeviceGui["image"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<a class="ui-btn" href="#page_' + ChildId + '">Open</a>');

		$('#page_body').append(
			'<div data-role="page" id="page_' + ChildId + '">' +
				'<div data-role="header">' +
					'<h1>Tight Home Control</h1>' +
				'</div>' +
				'<a class="ui-btn" href="#page_main">Back</a>' +
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

	DeviceGui["switch"]={};

	DeviceGui["switch"].Update=function(ChildId, DeviceId, Value) {
		var CurrentValue = $("#"+ChildId).val();
		Value = (Value=="1" || Value=="true" ? 1 : 0);
		if (Value==CurrentValue)
			return;
		$("#"+ChildId).val(Value).slider('refresh');
	}
	
	DeviceGui["switch"].ChangeState=function(ChildId,DeviceId) {
		var CurrentValue = $("#"+ChildId).val();
		//this.Update(ChildId,DeviceId,CurrentValue);
		//DeviceStates[DeviceId]=CurrentValue;
		StallDeviceUpdates[DeviceId]=true;
		$.get("/api/SetDeviceState "+DeviceId+" "+CurrentValue);
	}
	
	DeviceGui["switch"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<select id="' + ChildId + '" data-role="slider">' +
				'<option value="0">Off</option>' +
				'<option value="1">On</option>' +
			'</select>');

		$("#"+ChildId).on('slidestop', function( event ) {
			DeviceGui["switch"].ChangeState(ChildId,DeviceId);
		});
	}

/**** Level ****/

	DeviceGui["level"]={};

	DeviceGui["level"].Update=function(ChildId, DeviceId, Value) {
		if ($("#"+ChildId).val()!=Value) {
			$("#"+ChildId).val(Value);
			$("#"+ChildId).slider('refresh');
		}
	}
	
	DeviceGui["level"].ChangeState=function(ChildId, DeviceId) {
		StallDeviceUpdates[DeviceId]=true;
		$.get("/api/SetDeviceState "+DeviceId+" "+ $("#"+ChildId).val() );
	}
	
	DeviceGui["level"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		var Range = (DevicesInfo[DeviceId]["range"].length==0 ? [0,1] : DevicesInfo[DeviceId]["range"]);
		$(Parent).append(
			'<label for="' + ChildId + '">' + DeviceInfo["name"] + '</label>' +
			'<input data-type="range" id="' + ChildId + '" value="'+Range[0]+'" min="'+Range[0]+'" max="'+Range[1]+'" step="'+(Range[1]-Range[0])/100+'" data-highlight="true">');

		$(Parent).on("slidestop", "#"+ChildId, function(event) {
			DeviceGui["level"].ChangeState(ChildId,DeviceId);
		});
	}
	