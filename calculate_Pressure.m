function [pressure] = calculate_Pressure(wP_Hz, density, t_mm, D0_mm, DP_mm)
D0 = D0_mm*10^-3;
DP = DP_mm*10^-3;
wP = 2*pi*wP_Hz;
delD = DP-D0;
t = t_mm*10^-3;

pressure =((wP.^2).*density.*t.*delD)/4;
pressure = pressure/133.3;
end