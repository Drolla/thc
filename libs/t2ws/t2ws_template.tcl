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
# element to trigger the T2WS server to post-process the response data by 
# running the template engine. 
#     
#        IsTemplate   - If the value of this element is true (e.g. 1) the T2WS
#                       web server will run the template engine to post-process the
#                       HTTP response body before sending it to the HTTP client.
#
# Here is an example of a responder command that make usage of this response 
# element. It basically returns to the T2WS web server a file name and the 
# instruction to run the template engine. Since the T2WS server may not know 
# the specific file endings used by the template files it can be necessary to 
# specify explicitly the content type (as in the example), or to declare the 
# Mime type of the template file endings (see <t2ws::DefineMimeType>).
#
#       > proc Responder_GetFile {Request} {
#       >    set File [dict get $Request URITail]
#       >    return [dict create File $File IsTemplate 1 Content-Type .html]
#       > }
# 
# Another way to use the template engine is by calling it directly from the 
# response command using <t2ws::ProcessTemplate> or <t2ws::ProcessTemplateFile> :
#
#       > proc Responder_GetFile {Request} {
#       >    set File [dict get $Request URITail]
#       >    return [dict create Body [t2ws::ProcessTemplateFile $File] Content-Type .html]}
#       > }
# 
#
# Template file syntax:
#
# The template files or the unprocessed raw data have to contain pre-written 
# markup (e.g. HTML) together with Tcl code that is evaluated and replaced by 
# the template engine. This Tcl code can inserted in 2 manners into the 
# template files/raw data :
#
#    Inline Tcl code   - Backslash, command and variable substitution is 
#                        performed on each line. 
#    Tcl control line  - These lines are marked with the character '%' on the 
#                        line start. They are usually used to add control 
#                        constructs like conditions, loops, etc.
#
# The following example uses inline Tcl code (command and variable( as well as 
# Tcl control lines :
#
#    > <!DOCTYPE html>
#    > <html><body>
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
#


# Group: Template commands
# The following template commands are provided by this plugin.

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
	#    >    set f [open $File]
	#    >    set TemplateData [read $f]
	#    >    close $f
	#    >    return [dict create Body [ProcessTemplate $TemplateData]]
	#    > }
	#    
	# See also:
	#    <t2ws::ProcessTemplateFile>
	##########################

	# Inspired by: http://wiki.tcl.tk/18455
	
	proc t2ws::ProcessTemplate {Template {EvalVar ::t2ws::TemplateScript}} {
		set Script "set $EvalVar \"\"\n"
		foreach Line [split $Template "\n"] {
			if {[string index $Line 0]=="%"} {
				append Script [string range $Line 1 end] "\n"
			} else {
				append Script "append $EvalVar \[subst \{$Line\}\] \"\\n\"\n"
			}
		}
		
		uplevel #0 $Script
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


# Plugin the extension to the T2WS socket service

	proc t2ws::Plugin_Template {} {
		upvar Response Response

		if {[dict exists $Response ErrorStatus]} return

		if {[dict exists $Response IsTemplate] && [dict get $Response IsTemplate]} {
			dict set Response Body [ProcessTemplate [dict get $Response Body]] }
	}
	
	# Register the plugin
	t2ws::DefinePlugin t2ws::Plugin_Template



# Specify the t2ws version that is provided by this file:

	package provide t2ws_template 0.1


##################################################
# Modifications:
# $Log: $
##################################################