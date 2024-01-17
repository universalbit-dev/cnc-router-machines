
;Inkscape Lasertools G-code
;https://github.com/ChrisWag91/Inkscape-Lasertools-Plugin

G90	;Absolute programming
G21	;Programming in millimeters (mm)
M03 S1 ;Activate laser and set power to 0 (CUSTOM)


G0 X8.04 Y4.57
S0.1 F1200
G1 X102.38
G1 Y104.59
G1 X8.04
G1 Y4.57
S1
G00 X0 Y0

M05 S0	;Deactivate laser and set power to 0 (CUSTOM)
M02	;End of program
