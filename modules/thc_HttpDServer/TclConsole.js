function Ajax(Method,Url,Body,Callback) {
	var xHttp = new XMLHttpRequest();
	xHttp.onreadystatechange = function() { 
		if (xHttp.readyState==4)
			Callback(xHttp.status, xHttp.responseText);
	}
	xHttp.open(Method,Url,true);
	xHttp.send(Body==""?null:Body);
}

function AjaxJsonGet(Url,Callback) {
	Ajax("GET",Url,"",function(responseStatus,responseText) {
		Callback(responseStatus,responseText);
	});
}

var TclScriptHistory = [];
var CurrentTclScriptHistory = 0;

function CopyPastCommand(HistoryNbr) {
	var TclScriptField=document.getElementById("TclScript");
	TclScriptField.value=TclScriptHistory[HistoryNbr]; // Obj.innerText; // nodeValue; // textContent;
	TclScriptField.focus();
	setTimeout(function() {
		TclScriptField.selectionStart = TclScriptField.selectionEnd = TclScriptField.value.length
	}, 0);
}

document.onkeydown = checkKey;

function checkKey(e) {
	e = e || window.event;
	if (e.keyCode == '38') { // up arrow
		if (CurrentTclScriptHistory>0) {
			CurrentTclScriptHistory--;
			CopyPastCommand(CurrentTclScriptHistory);
		}
	}
	else if (e.keyCode == '40') { // down arrow
		if (CurrentTclScriptHistory<TclScriptHistory.length-1) {
			CurrentTclScriptHistory++;
			CopyPastCommand(CurrentTclScriptHistory);
		}
	}
}

function ExecuteTcl() {
	CurrentTclScriptHistory=TclScriptHistory.length;
	var TclScript = document.getElementById("TclScript").value;
	if (TclScript=="")
		return;
	Ajax("POST","eval",TclScript,function(HttpStatus,TclResult) {
		var Result = JSON.parse(TclResult);
		if (HttpStatus==406) {
			document.getElementById("TclScript").value += "\n";
			document.getElementById("TclScript").setAttribute("rows",
				Number(document.getElementById("TclScript").getAttribute("rows"))+1);
			document.getElementById("TclScript").style.backgroundColor="red";
		} else {
			document.getElementById("TclHistory").innerHTML +=
				'<span class="tclscript" onclick="CopyPastCommand('+TclScriptHistory.length+'); return false">'+htmlEscape(TclScript)+"</span><br>";
			TclScriptHistory[TclScriptHistory.length]=TclScript;
			CurrentTclScriptHistory=TclScriptHistory.length;
			if (Result.stdout!="")
				document.getElementById("TclHistory").innerHTML +=
					'<span class="tclstdout">'+htmlEscape(Result.stdout)+"</span><br>";
			if (Result.stderr!="")
				document.getElementById("TclHistory").innerHTML +=
					'<span class="tclstderr">'+htmlEscape(Result.stderr)+"</span><br>";
			if (Result.error!="")
				document.getElementById("TclHistory").innerHTML +=
					'<span class="tclerror">'+htmlEscape(Result.error)+"</span><br>";
			if (Result.result!="")
				document.getElementById("TclHistory").innerHTML +=
					'<span class="tclresult">'+htmlEscape(Result.result)+"</span><br>";
			document.getElementById("TclHistory").innerHTML += "<br>";

			document.getElementById("TclScript").value="";
			document.getElementById("TclScript").setAttribute("rows","1")
			document.getElementById("TclScript").style.backgroundColor="inherit";
		}
		window.scrollTo(0,document.body.scrollHeight);
	});
}

function htmlEscape(str) {
    return str
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/ /g, '&nbsp;')
        .replace(/\t/g, '&nbsp;&nbsp;&nbsp;')
        .replace(/\n/g, '<br>');
}

function ShowFile() {
	var FileName = document.getElementById("FileName").value;
	if (FileName=="")
		return;
	window.open('./showfile/'+FileName)
}

function DownloadFile() {
	var FileName = document.getElementById("FileName").value;
	if (FileName=="")
		return;
	window.open('./download/'+FileName)
}
