##########################################################################
# T2WS - Tiny Tcl Web Server
##########################################################################
# t2ws.tcl - Tiny HTTP Server main file
# 
# This file implements a tiny HTTP server.
#
# Copyright (C) 2016 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################


	package require Tcl 8.5
	package require t2ws


# Title: T2WS Template - Template engine for T2WS
#
# Group: Introduction
# This plugin extends the T2WS server with a template engine that process 
# template files or raw response data to generate the desired output file 
# (usually a HTML page). The plugin is loaded by executing the following 
# command :
#
#    > package require t2ws_template
#
# Once loaded the responder command can add the following response dictionary 
# field to trigger the T2WS server to post-process the response data by 
# running the template engine. 
#     
#        IsTemplate   - If the value of this field is true (e.g. 1) the T2WS
#                       web server will run the template engine to post-process the
#                       HTTP response body before sending it to the HTTP client.
#
# Here is an example of a responder command that make usage of this response 
# field. It basically returns to the T2WS web server a file name and the 
# instruction to run the template engine. Since the T2WS server may not know 
# the specific file endings used by the template files it can be necessary to 
# specify explicitly the content type (as in the example), or to declare the 
# Mime type of the template file endings (see <t2ws::DefineMimeType>).
#
#    > proc Responder_GetFile {Request} {
#    >    set File [dict get $Request URITail]
#    >    return [dict create File $File IsTemplate 1 Content-Type .html]
#    > }
#
# Template file syntax:
#
# The template files or the unprocessed raw data have to contain pre-written 
# markup (e.g. HTML) together with Tcl code that is evaluated and replaced by 
# the template engine. This Tcl code can inserted in 2 manners into the 
# template files/raw data :
#
#    * Inline Tcl code: Backslash, command and variable substitution is 
#                        performed on each line. 
#    * Tcl control line: These lines are marked with the character '%' on the 
#                        line start. They are usually used to add control 
#                        constructs like conditions, loops, etc.
#
# The template is evaluated inside a procedure that is part of the 't2ws' 
# namespace and that refers the 'Request' and 'Response' dictionary variables. 
# The response dictionary can be directly modified via the 'dict' command, or 
# via the commands <t2ws::SetResponse>, <t2ws::AddResponse> and
# <t2ws::UnsetResponse>.
#
# The following example contains inline Tcl code (command and variable) as well as 
# Tcl control lines and it reads some fields of the 'Request' dictionary :
#
#    > <!DOCTYPE html>
#    > <html><body>
#    >   <h1>Web client:</h1>
#    > %catch {
#    >     <p>Host: [dict get $Request Header host]</p>
#    >     <p>User-Agent: [dict get $Request Header user-agent]</p>
#    > %}
#    >   <h1>Tcl Plattform:</h1>
#    >   <table class="t_table">
#    >     <thead>
#    >       <tr><th>Name</th><th>Data</th></tr>
#    >     </thead>
#    >     <tbody>
#    > %foreach {Name Value} [array get tcl_platform] {
#    >       <tr><td>$Name</td><td>$Value</td></tr>
#    > %}
#    >     </tbody>
#    >   </table>
#    > </body></html>


# Register a T2WS plugin that handles invokes the template engine if a response 
# defines the IsTemplate field as true (e.g. 1).

	proc t2ws::Plugin_Template {Request} {
		upvar Response Response

		# Don't run the template engine if an error happened
		if {[dict exists $Response ErrorStatus]} return

		# Don't run the template engine if the IsTemplate field is not set to true
		if {![dict exists $Response IsTemplate] || ![dict get $Response IsTemplate]} return
		
		# Run the template engine
		set Script [GetTemplateScript [dict get $Response Body] TemplateEvalResult]
		eval $Script
		
		# Return the processed data
		dict set Response Body $TemplateEvalResult
	}
	
	# Register the plugin
	t2ws::DefinePlugin t2ws::Plugin_Template


# Group: Template commands
# This plugin provides additional template commands that allow evaluating 
# templates in a more explicit manner. <t2ws::GetTemplateScript> translates a 
# template into a script that can then be evaluated in a custom procedure. And 
# <t2ws::ProcessTemplate> and <t2ws::ProcessTemplateFile> evaluate respectively 
# template raw data and template files. Note that templates evaluated by these 
# commands cannot access the 'Request' and 'Response' dictionary variables! 

	##########################
	# Proc: t2ws::GetTemplateScript
	#    This command translates a template into a script that will generate the 
	#    processed template file if it is executed.
	#
	# Parameters:
	#    [Template] - Template data (e.g. HTML)
	#    [EvalVar]  - Temporary variable to use during the template processing
	#
	# Returns:
	#    Template script
	#    
	# Examples:
	#    > proc Responder_GetFile {Request} {
	#    >    # Read the file content
	#    >    set File [dict get $Request URITail]
	#    >    set f [open $File]
	#    >    set TemplateData [read $f]
	#    >    close $f
	#    >
	#    >    # Evaluate the template
	#    >    set Script [GetTemplateScript $Template TemplateEvalData]
	#    >    eval $Script
	#    >
	#    >    # Return the evaluated data
	#    >    return [dict create Body $TemplateEvalData Content-Type .html]
	#    > }
	#    
	# See also:
	#    <t2ws::ProcessTemplateFile>
	##########################

	# Inspired by: http://wiki.tcl.tk/18455
	
	proc t2ws::GetTemplateScript {Template {EvalVar ::t2ws::TemplateScript}} {
		set Script "set $EvalVar \"\"\n"
		foreach Line [split $Template "\n"] {
			if {[string index $Line 0]=="%"} {
				append Script [string range $Line 1 end] "\n"
			} else {
				append Script "append $EvalVar \[subst \{$Line\}\] \"\\n\"\n"
			}
		}
		return $Script
	}

	
	##########################
	# Proc: t2ws::ProcessTemplate
	#    This command processes a template provided in form of text and returns 
	#    the generated data.
	#
	# Parameters:
	#    [Template] - Template data (e.g. HTML)
	#    [EvalVar]  - Temporary variable to use during the template processing
	#
	# Returns:
	#    Evaluated template/generated data
	#    
	# Examples:
	#    > proc Responder_GetFile {Request} {
	#    >    # Read the file content
	#    >    set File [dict get $Request URITail]
	#    >    set f [open $File]
	#    >    set TemplateData [read $f]
	#    >    close $f
	#    >
	#    >    # Evaluate the template
	#    >    set TemplateEvalData [ProcessTemplate $TemplateData]
	#    >
	#    >    # Return the evaluated data
	#    >    return [dict create Body $TemplateEvalData Content-Type .html]
	#    > }
	#    
	# See also:
	#    <t2ws::ProcessTemplateFile>
	##########################

	proc t2ws::ProcessTemplate {Template {EvalVar ::t2ws::TemplateScript}} {
		uplevel #0 [GetTemplateScript $Template $EvalVar]
		set ProcessTemplate [set $EvalVar]
		unset $EvalVar
		return $ProcessTemplate
	}


	##########################
	# Proc: t2ws::ProcessTemplateFile
	#    This command processes a template provided in form of a file and 
	#    returns the generated data.
	#
	# Parameters:
	#    [TemplateFile] - Template file (e.g. HTML)
	#
	# Returns:
	#    Evaluated template/generated data
	#    
	# Examples:
	#    > proc Responder_GetFile {Request} {
	#    >    set File [dict get $Request URITail]
	#    >    switch [file extension $File] {
	#    >       .htmt {
	#    >          return [dict create Body [t2ws::ProcessTemplateFile $File] Content-Type .html]}
	#    >       default {
	#    >          return [dict create File $File]}
	#    >    }
	#    > }
	#    
	# See also:
	#    <t2ws::ProcessTemplate>
	##########################

	proc t2ws::ProcessTemplateFile {TemplateFile} {
		set f [open $TemplateFile]
		set Template [read $f]
		close $f
		
		return [ProcessTemplate $Template]
	}


# Specify the t2ws version that is provided by this file:

	package provide t2ws_template 0.2


##################################################
# Modifications:
# $Log: $
##################################################