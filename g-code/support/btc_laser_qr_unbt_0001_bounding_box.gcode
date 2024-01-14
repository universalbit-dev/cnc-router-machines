
;Inkscape Lasertools G-code
;https://github.com/ChrisWag91/Inkscape-Lasertools-Plugin

G90	;Absolute programming
G21	;Programming in millimeters (mm)
M03 S1 ;Activate laser and set power to 0 (CUSTOM)


G0 X4.19 Y4.08
S0.1 F1200
G1 X106.26
G1 Y106.16
G1 X4.19
G1 Y4.08
S1
G00 X0 Y0

M05 S0	;Deactivate laser and set power to 0 (CUSTOM)
M02	;End of program
