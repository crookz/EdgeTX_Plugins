SwitchPRO widget for EdgeTX
===========================

This widget provides a simple way to display the state of a 2- or 3-way switch. Features:
 - uses theme colors
 - display in full screen
 - custom labels per value
 - optionally display a custom label
 - responsive (adapts to different widget sizes)
 - configurable

Installation
============
Copy all contents of this folder to your transmitters SD card to WIDGETS/SwitchPRO

Configuration
=============
Source: where to get the value to display from. This can be a telemetry value, a variable, a stick or anything else
Label: usefull to see what the displayed value is. Leave empty do not show a label at all
SwUp: value to display if the switch is in the up position
SwMid: value to display if the switch is in the middle position
SwDown: value to display if the switch is in the down position
Percent: when on, ignore SwUp/SwMid/SwDown and show the source position as a percentage instead (for pots, sliders or switches)
PctLow: percentage shown when the source is at its minimum (-100 / 1000us)
PctHigh: percentage shown when the source is at its maximum (100 / 2000us). Values in between are scaled linearly, e.g. PctLow 50 and PctHigh 100 shows 75% at centre
LockSrc: (percent mode) a 3-position switch that locks the slider. Leave empty to disable
ActivePos: (percent mode) the LockSrc positions where the slider is active. On EdgeTX 2.11+ this is a drop-down (Off, Up, Mid, Down, Up+Mid, Mid+Down, Up+Down); on older firmware type any of U (up), M (middle), D (down), e.g. "U". All other positions count as locked. Next to the percentage a padlock (locked) or tick (active) is shown, followed by the lock switch name. Leave empty to disable