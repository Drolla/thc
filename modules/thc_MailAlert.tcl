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

######## Mail Alert ########

namespace eval thc_MailAlert {

	##########################
	# Proc: thc_MailAlert::Send
	#    Sends a mail message. Send sends a mail message to one or to multiple
	#    destination addresses. To use this command the command *mail* needs to 
	#    be available and configured.
	#
	# Parameters:
	#    -to <ToAddress> - Destination address. Multiple addresses can be 
	#                      specified by repeating this argument
	#    [-from <FromAddress>] - Sender address
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
	##########################

	proc Send {args} {
		# Parse the arguments
		set MailCmdArgs ""
		set MailAddressList {}
		set Message ""
		for {set a 0} {$a<[llength $args]} {incr a} {
			set arg [lindex $args $a]
			switch -- $arg {
				-to      {lappend MailAddressList [lindex $args [incr a]]}
				-from    {append MailCmdArgs " -r \"[lindex $args [incr a]]\""}
				-title   {append MailCmdArgs " -s \"[lindex $args [incr a]]\""}
				default {
					append Message "$arg\n"
				}
			}
		}
		
		# Send all messages through the U*n*x command 'mail'
		foreach MailAddress $MailAddressList {
			if {![catch {exec bash -c "echo \"$Message\" | mail $MailCmdArgs $MailAddress"}]} {
				Log {Alert sent to $MailAddress was successful} 3
			} else {
				Log {Alert sent to $MailAddress was failing} 3
			}
		}
	}

}; # End namespace thc_MailAlert