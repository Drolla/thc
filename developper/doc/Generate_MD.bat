::::::::::::::::::::::::::::::::::
:: Generate MarkDown Documentation
::::::::::::::::::::::::::::::::::
::
:: Specify the destination directory and documentation file definitions inside
:: the file _nd2md.settings:
::
::   set nd2md_DestDir <MD_DestinationDirectory>
::   array set nd2md_nd2md {
::     <TclFile1> <MdFile1>
::     <TclFile2> <MdFile2>
::     ... ...
::   }
::
:: Example:
::
::   set nd2md_DestDir "../../../thc.wiki"
::   array set nd2md_nd2md {
::     ../../bin/thc.tcl {THC-Core-functions.md}
::   }
::
::::::::::::::::::::::::::::::::::

:: General documentation
tclsh nd2md.tcl ^
   "THC-Introduction.txt" ^
   "THC-Getting-started.txt" ^
   "THC-Basics.txt" ^
   "THC-Developers.txt"

:: Core function documentation
tclsh nd2md.tcl ../../bin/thc.tcl

:: Module documentation
tclsh nd2md.tcl ^
   ../../modules/thc_MailAlert.tcl ^
   ../../modules/thc_HttpDServer.tcl ^
   ../../modules/thc_MeteoSwiss.tcl ^
   ../../modules/thc_OpenWeatherMap.tcl ^
   ../../modules/thc_RandomLight.tcl ^
   ../../modules/thc_Virtual.tcl ^
   ../../modules/thc_Rrd/thc_Rrd.tcl ^
   ../../modules/thc_Rrd/RrdManip.tcl ^
   ../../modules/thc_Timer/thc_Timer.tcl ^
   ../../modules/thc_Web/thc_Web.tcl ^
   ../../modules/thc_zWay/thc_zWay.tcl

:: Other documentation
tclsh nd2md.tcl ../../targets/Raspberry/Raspberry-installation.txt
tclsh nd2md.tcl ../../modules/thc_Web/thc_Web_API.tcl
tclsh nd2md.tcl -n ../../modules/thc_zWay/thc_zWay.js

:: Generate the index file
tclsh nd2md.tcl -x

:: Copy the used images to the destination
copy thc_Web.gif ..\..\..\thc.wiki