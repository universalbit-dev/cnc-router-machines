
;Inkscape Lasertools G-code
;https://github.com/ChrisWag91/Inkscape-Lasertools-Plugin

G90	;Absolute programming
G21	;Programming in millimeters (mm)
M03 S1 ;Activate laser and set power to 0 (CUSTOM)


G0 X3.72 Y5.99
S0.1 F1200
G1 X103.72
G1 Y105.99
G1 X3.72
G1 Y5.99
S1
G00 X0 Y0

M05 S0	;Deactivate laser and set power to 0 (CUSTOM)
M02	;End of program
