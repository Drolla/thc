/*************************************************************************
* THC - Tight Home Control
**************************************************************************
* thc_Web.js - THC client side web framework
*
* Copyright (C) 2015 Andreas Drollinger
**************************************************************************
* See the file "LICENSE" for information on usage and redistribution
* of this file, and for a DISCLAIMER OF ALL WARRANTIES.
*************************************************************************/

var DevicesInfo={};
var DeviceStates={};
var DeviceType="Classic";
var ColorMode=0;

function Switch(DeviceId) {
	if (DeviceStates[DeviceId]!="0" && DeviceStates[DeviceId]!="false" ) {
		$.get("/api/SetDeviceState "+DeviceId+" 0");
	} else {
		$.get("/api/SetDeviceState "+DeviceId+" 1");
	}
	UpdateNow();
}

function UpdateStates(NewDeviceStates) {
	DeviceStates=NewDeviceStates;
	$.each(NewDeviceStates, function(DeviceId, DeviceValue) {
		var ChildId = DeviceId.replace(/[.,]/g,"_");
		if (DevicesInfo[DeviceId]["type"]=="switch") {
			if (DeviceValue=="1" || DeviceValue=="true" ) {
				$("#"+ChildId+"_Pos").css("float","right");
				$("#"+ChildId).text("On");
			} else if (DeviceValue=="0" || DeviceValue=="false" ) {
				$("#"+ChildId+"_Pos").css("float","left");
				$("#"+ChildId).text("Off");
			} else {
				$("#"+ChildId+"_Pos").css("float","left");
				$("#"+ChildId).text("?");
			}
		} else {
			$("#"+ChildId).text(DeviceValue);
		}
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
	if (DeviceType=="Mobile") {
		DeviceType="Classic";
		$('link[href="thc_Web_mobile.css"]').attr({href : "thc_Web.css"});
	} else {
		DeviceType="Mobile";
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
	var Groups=[];
	$.each(DevicesInfo, function(DeviceId, DeviceInfo) {
		if (Groups.indexOf(DeviceInfo["group"])==-1) {
			Groups[Groups.length]=DeviceInfo["group"]; }
	});

	$("body").append('\
		<div class="title">\
		  <div class="title-left">\
		    <p class="title-text">Tight Home Control</p>\
		  </div>\
		  <div class="title-right" id="ViewSwitch">V</div>\
		  <div class="title-right" id="ColorSwitch">C</div>\
		</div>');
	$("#ViewSwitch").click(function() {ViewSwitch();});
	$("#ColorSwitch").click(function() {ColorSwitch();});

	$.each(Groups, function(GroupNbr, Group) {
		$("body").append('\
			<div class="group-header" id="group-header-'+GroupNbr+'"><p class="group-header-text">'+Group+'</p></div>\
			<div class="group-body" id="group-body-'+GroupNbr+'"></div>');
		$("#group-body-"+GroupNbr).hide();
		$('#group-header-'+GroupNbr).click(function() {
			ShowHideToggle("#group-body-"+GroupNbr);
		});


		$.each(DevicesInfo, function(DeviceId, DeviceInfo) {
			if (DeviceInfo["group"]!=Group) {
				return 0; // breaks the inner loop
			}
			
			var ChildId = DeviceId.replace(/[.,]/g,"_");
			BuildDeviceGui[DeviceInfo["type"]]($("#group-body-"+GroupNbr), ChildId, DeviceId, DeviceInfo);
		});
	});
	ResizeGui();
}

function ResizeGui() {
	var width=$(window).width();
	var MinWidth=(DeviceType=="Mobile" ? 700 : 250);
	if (width<2*MinWidth) {
		$(".widget-outsidecontainer").css({'width':'100%'});
	} else if (width<3*MinWidth) {
		$(".widget-outsidecontainer").css({'width':'50%'});
	} else if (width<4*MinWidth) {
		$(".widget-outsidecontainer").css({'width':'33.333%'});
	} else {
		$(".widget-outsidecontainer").css({'width':'25%'});
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

$(document).ready(function(){
	$("p").replaceWith("");
	//$("#DisplayInfo").html("<p>Window: Width=" + $(window).height() + ", Height=" + $(window).width() + ", PPI=" + getPPI() + "</p>");
	
	if ( /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(navigator.userAgent.toLowerCase()) ) {
		DeviceType="Mobile";
		$('link[href="thc_Web.css"]').attr({href : "thc_Web_mobile.css"});
	}

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

var BuildDeviceGui={};

/**** Default ****/

BuildDeviceGui[""] = function(Parent, ChildId, DeviceId, DeviceInfo) {
	$(Parent).append('\
		<div class="widget-outsidecontainer">\
		  <div class="widget-insidecontainer">\
		    <div class="widget-left">\
		      <p class="widget-text">' + DeviceInfo["name"] + '</p>\
		    </div>\
		    <div class="widget-right">\
		      <div class="widget-right-dv" id="' + ChildId + '_Pos"></div>\
		      <p class="widget-text" id="' + ChildId + '">?</p>\
		    </div>\
		  </div>\
		</div>\
	');
}

/**** Link ****/

BuildDeviceGui["link"] = function(Parent, ChildId, DeviceId, DeviceInfo) {
	$(Parent).append('\
		<div class="widget-outsidecontainer">\
		  <div class="widget-insidecontainer widget-link" id="' + ChildId + '_Cnt">\
		    <div class="widget-left">\
		      <p class="widget-text">' + DeviceInfo["name"] + '</p>\
		    </div>\
		  </div>\
		</div>\
	');

	$("#"+ChildId + "_Cnt").click(function() {
		window.open(DeviceInfo["data"], '_blank');
	});
}

/**** Module ****/

BuildDeviceGui["module"] = function(Parent, ChildId, DeviceId, DeviceInfo) {
	$(Parent).append('\
		<div class="widget-outsidecontainer">\
		  <div class="widget-insidecontainer widget-link" id="' + ChildId + '_Cnt">\
		    <div class="widget-left">\
		      <p class="widget-text">' + DeviceInfo["name"] + '</p>\
		    </div>\
		  </div>\
		</div>\
	');

	$("#"+ChildId + "_Cnt").click(function() {
		var ChildWin = window.open('module/'+DeviceInfo["data"]+'/index.html', '_blank');
	});
}

function GetActiveStyleSheets() {
	return [
		"../../"+(DeviceType=="Mobile" ? "thc_Web_mobile.css" : "thc_Web.css"),
		"../../"+(ColorMode%2 ? "thc_Web_ColorBlue.css" : "thc_Web_ColorDarkGray.css") ];
}


/**** Image ****/

function ShowHideImage(HtmlDeviceId,ImagePath) {
	if (!$(HtmlDeviceId).children('img').is(":hidden")) {
		$(HtmlDeviceId).children('img').hide(500)
	} else {
		$(HtmlDeviceId).children('img').attr("src", ImagePath);
		$(HtmlDeviceId).children('img').show(500);
	}
}

BuildDeviceGui["image"] = function(Parent, ChildId, DeviceId, DeviceInfo) {
	$(Parent).append('\
		<div class="widget-outsidecontainer-image">\
		  <div class="widget-insidecontainer widget-insidecontainer-image" id="' + ChildId + '_Cnt">\
		    <div class="widget-left">\
		      <p class="widget-image-text">' + DeviceInfo["name"] + '</p>\
		    </div>\
			 <img style="display:none"/>\
		  </div>\
		</div>\
	');

	$("#"+ChildId + "_Cnt").click(function() {
		ShowHideImage("#"+ChildId + "_Cnt","/api/GetDeviceData "+DeviceId);
	});
}

/**** Switch ****/

BuildDeviceGui["switch"] = function(Parent, ChildId, DeviceId, DeviceInfo) {
	$(Parent).append('\
		<div class="widget-outsidecontainer">\
		  <div class="widget-insidecontainer">\
		    <div class="widget-left">\
		      <p class="widget-text">' + DeviceInfo["name"] + '</p>\
		    </div>\
		    <div class="widget-right-switch" id="' + ChildId + '_Cnt">\
		      <div class="switch-position" id="' + ChildId + '_Pos"></div>\
		      <p class="switch-text" id="' + ChildId + '">?</p>\
		    </div>\
		  </div>\
		</div>\
	');

	$("#"+ChildId + "_Cnt").click(function() {
		Switch(DeviceId);
	});
}
