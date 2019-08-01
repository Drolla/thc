##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_server.tcl - THC mail alert module
# 
# This module implements a mail sender function.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Mail alert
#
# This module provides functions to send mail alerts.

######## Mail Alert ########

namespace eval thc_MailAlert {


	##########################
	# Proc: thc_MailAlert::Configure
	#    Configures the mail delivery method. Mails can be delivered either via 
	#    a custom mail procedure (method=custom), or using the Tcl smtp 
	#    package. For this second case the mail delivery can either be managed 
	#    by the main THC Tcl process (method=direct_sync) or by a specific Tcl
	#    process (method=direct_async). This latest method avoids eventual 
	#    interruptions of the main THC Tcl process in case the SMTP server 
	#    response is delayed.
	#
	# Parameters:
	#    -method <DeliveryMethod> - Mail delivery method. Has to be 'custom', 
	#                               'direct_sync' or 'direct_async' (default)
	#
	#    [-custom_command <CustomCommand>] - Specifies the custom mail command
	#                               that will be called if the custom delivery 
	#                               method is selected. The argument list of the 
	#                               custom command and the use of the Unix mail
	#                               command 'mail' is shown in the example 
	#                               below.
	#                               
	#
	#    [-direct_args <Direct delivery arguments>] - Arguments transferred to 
	#                               smtp::sendmessage if one of the direct mail
	#                               delivery methods is selected
	#
	#    -debug 0|1 - If set to 1 some additional log information are displayed 
	#                 that help debugging the email delivery method. Default: 0
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > # 1)
	#    > thc_MailAlert::Configure -method direct_async
	#    >    -direct_args {-servers mail.my_host.com -ports 25}
	#    >
	#    > # 2)
	#    > thc_MailAlert::Configure {*}{
	#    >    -method custom
	#    >    -custom_command mail_custom_send
	#    > }
	#    > 
	#    > proc mail_custom_send {Title Message RecipientList From} {
	#    >    # Backslash double quotes
	#    >    regsub -all "\"" $Message "\\\"" Message
	#    >    regsub -all "\"" $Title "\\\"" Title
	#    > 
	#    >    # Call the Unix mail command to send the message
	#    >    exec bash -c "echo \"$Message\" | mail -s $Title -r $From $RecipientList"
	#    > }
	#    
	# See also:
	#    <thc_MailAlert::Send>
	##########################
	
	variable Options
	array set Options {
		-method direct_async
		-custom_command ""
		-direct_args {}
		-debug 0
	}

	proc Configure {args} {
		variable Options
		
		if {$args=={}} {
			return [array get Options]
		} elseif {[lindex $args 0]=="init"} {
		} elseif {[llength $args]==1} {
			return $Options($args)
		} else {
			array set Options $args
		}
		
		Init
	}
	
	proc Init {} {
		variable Options
		if {[catch {
			if {$Options(-method)=="custom"} {
				InitCustom
			} elseif {$Options(-method)=="direct_async"} {
				InitDirectAsync
			} elseif {$Options(-method)=="direct_sync"} {
				InitDirectSync
			} else {
				error "Mail delivery method '$Options(-method)' unknown"
			}
		}]} {
			error "Error initializing mail: $::errorInfo"
		}
	}


	##########################
	# Proc: thc_MailAlert::Send
	#    Sends a mail message. Send sends a mail message to one or to multiple
	#    destination addresses. To use this command the command *mail* needs to 
	#    be available and configured.
	#
	# Parameters:
	#    -to <ToAddress> - Destination address. Multiple addresses can be 
	#                      specified by repeating this argument
	#    [-from <From>] - Sender address. Default: localhost
	#    [-title <Title>] - Message title
	#    Message - Mail message
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc_MailAlert::Send -to knopf@vaucher.ch -to 0041791234567@sms.ecall.ch \
	#    >                     -from myhome.vaucher@bluewin.ch -title "Alarm alert" \
	#    >                     "Sensor $Sensor triggered"
	#    
	# See also:
	#    <thc_MailAlert::Configure>
	##########################

	proc Send {args} {
		variable Options
		
		# Default options
		set RecipientList {}
		set From {localhost}
		set Message {}
		set Title ""

		# Parse the arguments, parse first all options, and then the message lines
		for {set a 0} {$a<[llength $args]} {incr a} {
			set arg [lindex $args $a]
			switch -regexp -- $arg {
				^--$     {incr a; break}
				^-to$    {lappend RecipientList [lindex $args [incr a]]}
				^-from$  {set From [lindex $args [incr a]]}
				^-title$ {set Title [lindex $args [incr a]]}
				^-       {error "Unknown option $arg"}
				default  {break}
			}
		}
		set Message [join [lrange $args $a end] "\n"]
		
		# Mail delivery initialization
		Init
		
		# Mail delivery using custom mail program
		if {$Options(-method)=="custom"} {
			SendCustom $Title $Message $RecipientList $From

		# Asynchronous message delivery (using separate thread)
		} elseif {$Options(-method)=="direct_async"} {
			variable MailSendThId
			thread::send -async $MailSendThId \
				[list SendDirect $Title $Message $RecipientList $From {*}$Options(-direct_args)]

		# Synchronous message delivery (without using separate thread)
		} else {
			SendDirect $Title $Message $RecipientList $From {*}$Options(-direct_args)
		}
	}

	proc SendCustom {Title Message RecipientList From} {
		variable Options
		
		# Send the message via the custom mail program
		if {![catch [list $Options(-custom_command) $Title $Message $RecipientList $From]]} {
			Log {Alert sent to $RecipientList was successful} 3
		} else {
			Log {Alert sent to \{$RecipientList\} was failing} 3
			if {$Options(-debug)} {
				Log {error message: $::errorInfo} 3 }
		}
	}

	proc SendDirect {Title Message RecipientList From args} {
		# Send all messages using the mime and smtp packages
		set tok [mime::initialize -canonical text/plain -encoding 7bit -string $Message]
		mime::setheader $tok Subject $Title
		if {![catch {
			if {$Options(-debug)} {
				Log {Executed command: smtp::sendmessage $tok -originator $From -recipients [join $RecipientList ","] {*}$args} 3 }
			smtp::sendmessage $tok -originator $From -recipients [join $RecipientList ","] {*}$args
		}]} {
			Log {Alert sent to $RecipientList was successful} 3
		} else {
			Log {Alert sent to $RecipientList was failing} 3
			if {$Options(-debug)} {
				Log {error message: $::errorInfo} 3 }
		}
		# Destroys the MIME part represented by token
		mime::finalize $tok
	}
	
	proc InitCustom {} {
	}
	
	proc InitDirectAsync {} {
		variable MailSendThId
		if {![info exists MailSendThId]} {
			package require Thread
			set MailSendThId [thread::create]
			thread::send $MailSendThId {package require mime; package require smtp}
			thread::send $MailSendThId "set MainThId [thread::id]"
			thread::send $MailSendThId {proc Log {Text {Level 3}} {thread::send $::MainThId [list Log [uplevel 1 "subst \{$Text\}"] $Level]}}
			thread::send $MailSendThId [list proc SendDirect [info args SendDirect] [info body SendDirect]]
		}
	}

	proc InitDirectSync {} {
		package require mime
		package require smtp
	}
	

}; # End namespace thc_MailAlert