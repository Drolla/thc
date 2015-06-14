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
var DisplayType="Classic";
var ColorMode=0;

var DeviceGui={};

function UpdateStates(NewDeviceStates) {
	DeviceStates=NewDeviceStates;
	$.each(NewDeviceStates, function(DeviceId, DeviceValue) {
		var ChildId = DeviceId.replace(/[.,]/g,"_");
		var DeviceType = DevicesInfo[DeviceId]["type"];
		DeviceGui[ DeviceType ].Update(ChildId,DeviceId,DeviceValue);
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
			var DeviceType = DeviceInfo["type"];
			DeviceGui[DeviceType].Create($("#group-body-"+GroupNbr), ChildId, DeviceId, DeviceInfo);
		});
	});
	ResizeGui();
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

$(document).ready(function(){
	$("p").replaceWith("");
	//$("#DisplayInfo").html("<p>Window: Width=" + $(window).height() + ", Height=" + $(window).width() + ", PPI=" + getPPI() + "</p>");
	
	if ( /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(navigator.userAgent.toLowerCase()) ) {
		DisplayType="Mobile";
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


/**** Default ****/

	DeviceGui[""]={};
	
	DeviceGui[""].Update = function(ChildId, DeviceId, Value) {
		$("#"+ChildId).text(Value);
	}
	
	DeviceGui[""].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append('\
			<div class="item-outsidecontainer">\
			  <div class="item-insidecontainer">\
			    <div class="item-left">\
			      <p class="item-text">' + DeviceInfo["name"] + '</p>\
			    </div>\
			    <div class="item-right">\
			      <div class="item-right-dv" id="' + ChildId + '_Pos"></div>\
			      <p class="item-text" id="' + ChildId + '">?</p>\
			    </div>\
			  </div>\
			</div>\
		');
	}
	
/**** Link ****/

	DeviceGui["link"]={};

	DeviceGui["link"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append('\
			<div class="item-outsidecontainer">\
			  <div class="item-insidecontainer cursor-pointer" id="' + ChildId + '_Cnt">\
			    <div class="item-left">\
			      <p class="item-text">' + DeviceInfo["name"] + '</p>\
			    </div>\
			  </div>\
			</div>\
		');
	
		$("#"+ChildId + "_Cnt").click(function() {
			window.open(DeviceInfo["data"], '_blank');
		});
	}
	
/**** Module ****/

	DeviceGui["module"]={};

	DeviceGui["module"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append('\
			<div class="item-outsidecontainer">\
			  <div class="item-insidecontainer cursor-pointer" id="' + ChildId + '_Cnt">\
			    <div class="item-left">\
			      <p class="item-text">' + DeviceInfo["name"] + '</p>\
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
			"../../"+(DisplayType=="Mobile" ? "thc_Web_mobile.css" : "thc_Web.css"),
			"../../"+(ColorMode%2 ? "thc_Web_ColorBlue.css" : "thc_Web_ColorDarkGray.css") ];
	}


/**** Image ****/

	DeviceGui["image"]={};

	DeviceGui["image"].ShowHideImage = function (HtmlDeviceId,ImagePath) {
		if (!$(HtmlDeviceId).children('img').is(":hidden")) {
			$(HtmlDeviceId).children('img').hide(500)
		} else {
			$(HtmlDeviceId).children('img').attr("src", ImagePath);
			$(HtmlDeviceId).children('img').show(500);
		}
	}
	
	DeviceGui["image"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append('\
			<div class="item-outsidecontainer-image">\
			  <div class="item-insidecontainer item-insidecontainer-image" id="' + ChildId + '_Cnt">\
			    <div class="item-left">\
			      <p class="item-image-text">' + DeviceInfo["name"] + '</p>\
			    </div>\
				 <img style="display:none"/>\
			  </div>\
			</div>\
		');
	
		$("#"+ChildId + "_Cnt").click(function() {
			DeviceGui["image"].ShowHideImage("#"+ChildId + "_Cnt","/api/GetDeviceData "+DeviceId);
		});
	}

/**** Switch ****/

	DeviceGui["switch"]={};

	DeviceGui["switch"].Update=function(ChildId, DeviceId, Value) {
		if (Value=="1" || Value=="true" ) {
			$("#"+ChildId+"_Pos").css("float","right");
			$("#"+ChildId).text("On");
		} else if (Value=="0" || Value=="false" ) {
			$("#"+ChildId+"_Pos").css("float","left");
			$("#"+ChildId).text("Off");
		} else {
			$("#"+ChildId+"_Pos").css("float","left");
			$("#"+ChildId).text("?");
		}
	}
	
	DeviceGui["switch"].ChangeState=function(ChildId,DeviceId) {
		var NewValue=(DeviceStates[DeviceId]=="0" || DeviceStates[DeviceId]=="false" ? 1 : 0);
		$.get("/api/SetDeviceState "+DeviceId+" "+NewValue);
		this.Update(ChildId,DeviceId,NewValue);
	}
	
	DeviceGui["switch"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append('\
			<div class="item-outsidecontainer">\
			  <div class="item-insidecontainer">\
			    <div class="item-left">\
			      <p class="item-text">' + DeviceInfo["name"] + '</p>\
			    </div>\
			    <div class="item-right-switch" id="' + ChildId + '_Cnt">\
			      <div class="switch-position" id="' + ChildId + '_Pos"></div>\
			      <p class="switch-text" id="' + ChildId + '">?</p>\
			    </div>\
			  </div>\
			</div>\
		');
	
		$("#"+ChildId + "_Cnt").click(function() {
			DeviceGui["switch"].ChangeState(ChildId,DeviceId);
		});
	}

/**** level ****/

	DeviceGui["level"]={};

	DeviceGui["level"].Update=function(ChildId, DeviceId, Value) {
		var Range = (DevicesInfo[DeviceId]["range"].length==0 ? [0,1] : DevicesInfo[DeviceId]["range"]);
		Value = (Value-Range[0])/(Range[1]-Range[0]);
		$("#"+ChildId+"_Pos").offset({left:$("#"+ChildId+"_Cnt").offset().left+($("#"+ChildId+"_Cnt").width()-$("#"+ChildId+"_Pos").width())*Value});
	}
	
	DeviceGui["level"].ChangeState=function(ChildId, DeviceId, Event) {
		var Range = (DevicesInfo[DeviceId]["range"].length==0 ? [0,1] : DevicesInfo[DeviceId]["range"]);
		var Value=(Event.pageX-$("#"+ChildId+"_Cnt").offset().left)/$("#"+ChildId+"_Cnt").width()
		Value=Math.min(Math.max(Value,0),1);
		Value=Range[0]+Value*(Range[1]-Range[0]);
		$.get("/api/SetDeviceState "+DeviceId+" "+Value);
		this.Update(ChildId,DeviceId,Value);
	}
	
	DeviceGui["level"].Create = function(Parent, ChildId, DeviceId, DeviceInfo) {
		$(Parent).append('\
			<div class="item-outsidecontainer">\
			  <div class="item-insidecontainer">\
			    <div class="item-center" id="' + ChildId + '_Cnt">\
			      <div class="level-position" id="' + ChildId + '_Pos"></div>\
			      <div class="item-text-center" id="' + ChildId + '_Pos">\
			      	<p display class="item-text-center">' + DeviceInfo["name"] + '</p>\
					</div>\
			    </div>\
			  </div>\
			</div>\
		');
	
		$("#"+ChildId + "_Cnt").click(function(e) {
				DeviceGui["level"].ChangeState(ChildId, DeviceId, e);
		});
		$("#"+ChildId + "_Cnt").on("mousemove",function(e) {
			if (e.buttons==1) {
				DeviceGui["level"].ChangeState(ChildId, DeviceId, e); }
		});
	}
	