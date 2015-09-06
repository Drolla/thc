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


function Select_PageNewTimer() {
	$.getJSON('/api/GetDeviceInfo', function(DevicesInfo) {
		$.each(DevicesInfo, function(DeviceId, DeviceInfo) {
			if (DeviceInfo["type"]=="switch")
				$("#DeviceSelection").append('<option value="'+DeviceId+'">'+DeviceId+'</option>');
		});
	});

	// Initialize the new page 
	$.mobile.initializePage();

	// Navigate to the new page
	$.mobile.changePage("#page_newtimer");
}

function AddDefinedAdd() {
	var JobDef={};
	JobDef['time']=$('#DateTime').val();
	JobDef['device']=$('#DeviceSelection').val();
	JobDef['command']=$('#DeviceState').val();
	JobDef['repeat']=$('#RepeatTime').val();
	$.get("/api/thc_Timer_Define "+JSON.stringify(JobDef), function(Result) {
		// Select_PageMain(); // This doesn't work, the page isn't rendered correctly
		window.location.replace( window.location.href.split('#')[0] );
	}) .fail(function() {
		alert( "The form contains invalid date. Please correct!" );
	})
};

function AddDefinedCancel() {
	$.mobile.initializePage();
	$.mobile.changePage("#page_main");
}

function DeleteTimer(TimerId) {
	if (!confirm("Are you sure you want to delete timer '"+TimerId+"'?"))
		return;
	$.get('/api/thc_Timer_Delete '+TimerId, function() {
		// Select_PageMain(); // This doesn't work, the page isn't rendered correctly
		window.location.replace( window.location.href.split('#')[0] );
	});
}

function Select_PageMain() {
	$.getJSON('/api/thc_Timer_List', function(TimerInfo) {
		$("#page_main_content").empty();
		$.each(TimerInfo, function(TimerId, TimerData) {
			$("#page_main_content").append(
				'<div data-role="collapsible" data-collapsed="false">' +
					'<h4>'+TimerId+'</h4>' +
					'<ul data-role="listview" data-inset="true">' +
						'<li class="ui-field-contain">' +
							'<label for="' + TimerId + '_Time">Time</label>' +
							'<label id="' + TimerId + '_Time">'+TimerData["time"]+'</label>' +
						'</li>' +
						'<li class="ui-field-contain">' +
							'<label for="' + TimerId + '_Repeat">Repeat</label>' +
							'<label id="' + TimerId + '_Repeat">'+TimerData["repeat"]+'</label>' +
						'</li>' +
						'<li class="ui-field-contain">' +
							'<label for="' + TimerId + '_Device">Device</label>' +
							'<label id="' + TimerId + '_Device">'+TimerData["device"]+'</label>' +
						'</li>' +
						'<li class="ui-field-contain">' +
							'<label for="' + TimerId + '_Command">Command</label>' +
							'<label id="' + TimerId + '_Command">'+TimerData["command"]+'</label>' +
						'</li>' +
					 	'<a data-role="button" data-inline="true" onclick="DeleteTimer(\''+TimerId+'\')" rel="external">Delete</a>' + 
					'</ul>' +
				'</div>'
			);
		});

		// Initialize the new page 
		$.mobile.initializePage();

		// Navigate to the new page
		$.mobile.changePage("#page_main");
	} );
}

$(document).ready(function(){
	// Initialize the date/time picker widget
	$('#DateTime').datetimepicker();

	Select_PageMain();
});
