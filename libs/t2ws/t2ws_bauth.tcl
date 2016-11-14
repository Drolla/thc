##########################################################################
# T2WS - Tiny Tcl Web Server
##########################################################################
# t2ws_bauth.tcl - Basic authentication plugin for T2WS
# 
# This file provides a basic authentication plugin the T2WS web server
#
# Copyright (C) 2016 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: T2WS BAuth - Basic Authentication support for T2WS
#
# Group: Introduction
#
# This plugin provides basic HTTP authentication to the T2WS server. It is 
# loaded and enabled by executing the following commands :
#
#    > package require t2ws::bauth
#    > t2ws::EnablePlugin $Port t2ws::bauth
#
# After loading this package the available login credentials have to be defined 
# by defining the dictionary variable 't2ws::bauth::LoginCredentials' :
#
#    > set t2ws::bauth::LoginCredentials [dict create \
#    >    <UserName1> <UserPassword1> \
#    >    <UserName2> <UserPassword2> \
#    >    ... \
#    > ]
#
# Once this setup is completed the T2WS web server requires a basic 
# authentication from the HTTP clients. For HTTP requests that use known login
# credentials the plugin adds to the request dictionary the element 'User' 
# that contains the recognized user name and that can be read by the responder 
# commands.
#
#
# Group: Security considerations
#
# The basic HTTP authentication doesn't provide any encryption. Using HTTP 
# the login credentials can easily be decoded. A secure connection can only 
# be guaranteed if basic authentication is used in combination with a secure 
# SHTTP connection (using the SSL/TLS extension).


# Package requirements, configurations and variables

	package require Tcl 8.5
	package require t2ws
	package require base64

	namespace eval t2ws::bauth {}


# Group: Configuration

# Specification of the configuration options of the package, their default 
# values and the validity check.

	namespace eval t2ws::bauth {
		variable ConfigDefinitions [dict create \
			-realm {"T2WS Web Server" 1} \
		]
	}

	##########################
	# Proc: t2ws::bauth::Configure
	#    Set and get T2WS Basic Authentication plugin configuration options. 
	#    This command can be called in 3 different ways :
	#
	#       t2ws::bauth::Configure - Returns the currently defined T2WS configuration
	#       t2ws::bauth::Configure <Option> - Returns the value of the provided option
	#       t2ws::bauth::Configure <Option/Value pairs> - Define options with new values
	#
	#    The following options are supported :
	#
	#       -realm - HTTP attribute used for the HTTP basic authentication request. 
	#                This is a simple string that defines the scope of the 
	#                protection space. Default: 'T2WS Web Server'
	#
	# Parameters:
	#    [Option1] - Configuration option 1
	#    [Value1]  - Configuration value 1
	#    ...       - Additional option/value pairs can follow
	#
	# Returns:
	#    Configuration options (if the command is called in way 1 or 2)
	#    
	# Examples:
	#    > t2ws::bauth::Configure
	#    > -> -realm {T2WS Web Server}
	#    > t2ws::bauth::Configure -realm "My home control"
	##########################

	proc t2ws::bauth::Configure {args} {
		variable Config
		variable ConfigDefinitions
		t2ws::ConfigureInt Config $ConfigDefinitions {*}$args
	}

	# Define the default options
	t2ws::bauth::Configure SetDefaults

	# Dictionary of user passwords (empty for the moment)
	namespace eval t2ws::bauth {
		variable LoginCredentials [dict create]
	}

# Plugin implementation
	
# Register a T2WS plugin that handles invokes the template engine if a response 
# defines the IsTemplate field as true (e.g. 1).

	# Plugin command
	proc t2ws::bauth::PluginCmd {} {
		variable LoginCredentials
		upvar Request Request
		upvar Response Response

		# Get the authorization header attribute, decode it and get the user and 
		# password.
		catch {
			# Get authorization header attribute ('Basic QWRtaW46UGFzc3dvcmQ=')
			set AuthorizationLine [dict get $Request Header authorization]
			# Extract the Base64 coded authorization string ('QWRtaW46UGFzc3dvcmQ=')
			regexp {Basic\s+(.*)$} $AuthorizationLine {} AuthorizationBase64
			# Decode the authorization string ('Admin:Password')
			set Authorization [base64::decode $AuthorizationBase64]
			# Extract user name and password
			regexp {^(.*):(.*)$} $Authorization {} User Password
		}
		
		# Check that the user is defined and the provided password correct. 
		# Otherwise request the authentication by setting the status to 401 and
		# defining the WWW-Authenticate header attribute.
		if {![info exists User] || ![info exists Password] ||
		    ![dict exists $LoginCredentials $User] ||
			 $Password!=[dict get $LoginCredentials $User]
		} {
			puts "  -> ErrorStatus 401"
			dict set Response ErrorStatus 401
			dict set Response ErrorHeader WWW-Authenticate {Basic realm="T2WS Demo"}
			dict set Response ErrorBody "401 - Unauthorized, basic HTTP authentication is required!"
			return
		}
		
		# Add the user attribute to the request dictionary for the responder command
		dict set Request User $User
	}
	
	# Register the plugin
	t2ws::DefinePlugin t2ws::bauth Pre t2ws::bauth::PluginCmd

# Specify the t2ws_bauth version that is provided by this file:
package provide t2ws::bauth 0.2


# Group: How it works?
#
# This plugin checks each HTTP request for the existence of the authorization 
# header attribute. Example :
# 
#    > Authorization: Basic <LoginCredentials>
#
# If this attribute doesn't exist, or if the login credentials cannot be decoded 
# and matched with user/password information defined by the variable 
# 't2ws::bauth::LoginCredentials', a 401-unauthorized HTTP response is returned
# together with an authentication request ('WWW-Authenticate') :
#
#    > WWW-Authenticate: Basic realm="t2ws demo"
#
# All usual browsers will then open a new window and request that a user name 
# and password are provided. Once the information is provided the browser will
# use the 'Authorization' header attribute until the current session is closed.


##################################################
# Modifications:
# $Log: $
##################################################