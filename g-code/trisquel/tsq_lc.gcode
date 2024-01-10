
;Inkscape Lasertools G-code
;https://github.com/ChrisWag91/Inkscape-Lasertools-Plugin

G90	;Absolute programming
G21	;Programming in millimeters (mm)
M03 S1 ;Activate laser and set power to 0 (CUSTOM)


G0 X49.004999999999995 Y5.7
S0.1 F1200
G1 Y92.51
G1 Y49.105000000000004
G1 X3.65
G1 X94.36
G1 X49.004999999999995
S1
G00 X0 Y0

M05 S0	;Deactivate laser and set power to 0 (CUSTOM)
M02	;End of program
