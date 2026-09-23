SwitchPRO widget for EdgeTX
===========================

This widget provides a simple way to display the state of a 2- to 8-way switch. Features:
 - uses theme colors
 - display in full screen
 - custom labels per value
 - optionally display a custom label
 - responsive (adapts to different widget sizes)
 - configurable

Installation
============
Copy all contents of this folder to your transmitters SD card to WIDGETS/BDSwitchPRO

Configuration
=============
Source: where to get the value to display from. This can be a telemetry value, a variable, a stick or anything else
Label: usefull to see what the displayed value is. Leave empty do not show a label at all
Boxes: how many positions/boxes to divide the source's range into (2-8). Defaults to 3
Box1-Box8: text to display for each box, in order from the lowest end of the source's range to the highest. Only the first "Boxes" of these are used