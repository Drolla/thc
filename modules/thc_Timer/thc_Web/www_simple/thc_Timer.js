/*************************************************************************
* THC - Tight Home Control
**************************************************************************
* thc_Timer.js - Web access for the timer module
*
* Copyright (C) 2015 Andreas Drollinger
**************************************************************************
* See the file "LICENSE" for information on usage and redistribution
* of this file, and for a DISCLAIMER OF ALL WARRANTIES.
*************************************************************************/


function AddTimer() {
	$("body").empty();
	$("body").append('\
		<div class="title">\
		  <div class="title-left">\
		    <p class="title-text">Add new timer</p>\
		  </div>\
		</div>\
		<p class="entry_title"><br><br>Date and time</p>\
		<p class="entry_comment">Format: YYYY/MM/DD HH:MM</p>\
		<input type="text" id="datetime" class="entry_field"/>\
		<p class="entry_title">Repeat</p>\
		<p class="entry_comment">Format: {YY}Y{MM}M{WW}W{DD}D{hh}h{mm}m{ss}s, comment: keep empty if no repetition is required</p>\
		<select id="repeattime" class="entry_field">\
			<option value="">no repeat</option>\
			<option value="1h">1h</option>\
			<option value="4h">4h</option>\
			<option value="12h">12h</option>\
			<option value="1D">1D</option>\
			<option value="1W">1W</option>\
			<option value="1M">1M</option>\
			<option value="1Y">1Y</option>\
		</select>\
		<div></div>\
		<p class="entry_title">Device:</p>\
		<p class="entry_comment">Select the device</p>\
		<select id="DeviceSelection" class="entry_field"></select>\
		<p class="entry_title">State:</p>\
		<p class="entry_comment">Select the state</p>\
		<select id="DeviceState" class="entry_field">\
			<option value="On">On</option>\
			<option value="Off">Off</option>\
			<option value="Switch">Switch</option>\
			<option value="Switch">Value</option>\
		</select>\
		<div></div>\
		<div class="button_row">\
		   <p class="button" id="Add_Cnt">Add</p>\
		   <p class="button" id="Cancel_Cnt">Cancel</p>\
		</div>');

	$('#datetime').datetimepicker();

	$.getJSON('/api/GetDeviceInfo', function(DevicesInfo) {
		$.each(DevicesInfo, function(DeviceId, DeviceInfo) {
			if (DeviceInfo["type"]=="switch")
				$("#DeviceSelection").append('<option value="'+DeviceId+'">'+DeviceId+'</option>');
		});
	});

	$("#Add_Cnt").click(function() {
		var JobDef={};
		JobDef['time']=$('#datetime').val();
		JobDef['device']=$('#DeviceSelection').val();
		JobDef['command']=$('#DeviceState').val();
		JobDef['repeat']=$('#repeattime').val();
		$.get("/api/TimerDefine "+JSON.stringify(JobDef), function(Result) {
			BuildGui();
		}) .fail(function() {
			alert( "The form contains invalid date. Please correct!" );
		})
	});

	$("#Cancel_Cnt").click(function() {
		BuildGui();
	});
}

function DeleteTimer(TimerId) {
	if (!confirm("Are you sure you want to delete timer '"+TimerId+"'?"))
		return;
	$.get('/api/TimerDelete '+TimerId, function(data) {
		BuildGui();
	});
}

function BuildGui() {
	$.getJSON('/api/TimerList', function(TimerInfo) {
	
		$("body").empty();
		$("body").append('\
			<div class="title">\
			  <div class="title-left">\
			    <p class="title-text">THC timer module</p>\
			  </div>\
			</div>\
		  <div class="button_row">\
			  <p class="button" id="Add_Cnt">Add</p>\
			  <p class="button" id="Close_Cnt">Close</p>\
		  </div>');
	
		$("#Add_Cnt").click(function() {
			AddTimer();
		});
		$("#Close_Cnt").click(function() {
			close();
		});
	
		$.each(TimerInfo, function(TimerId, TimerData) {
			$("body").append('\
				<div class="group-header"><p class="group-header-text">'+TimerId+'</p></div>');
			$("body").append('\
				<div class="group-body"><table>\
				<tr><td>time</td><td>'+TimerData["time"]+'</td></tr>\
				<tr><td>repeat</td><td>'+TimerData["repeat"]+'</td></tr>\
				<tr><td>device</td><td>'+TimerData["device"]+'</td></tr>\
				<tr><td>command</td><td>'+TimerData["command"]+'</td></tr>\
				</table></div>');
	
			$("body").append('\
				<div class="button_row">\
				<p class="button" id="' + TimerId + '_Cnt">Delete</p>\
			</div>');
	
			$("#"+TimerId + "_Cnt").click(function() {
				DeleteTimer(TimerId);
			});
	
		});
	});
}

$(document).ready(function(){
	var ActiveStyleSheets=opener.GetActiveStyleSheets();
	for (var i=0; i<ActiveStyleSheets.length; i++) {
		$('head').append('<link rel="stylesheet" href="'+ActiveStyleSheets[i]+'" type="text/css" />');
	}
	BuildGui();
});
