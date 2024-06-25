function [density, D0_mm] = Cuff_Calibrate(Pd_mmHg, Ps_mmHg, Dd_mm, Ds_mm, wd_Hz, ws_Hz, t_mm)
Pd = Pd_mmHg*133.3;
Ps = Ps_mmHg*133.3;
Dd = Dd_mm*10^-3;
Ds = Ds_mm*10^-3;
wd = 2*pi*wd_Hz;
ws = 2*pi*ws_Hz;
delD = Ds-Dd;
t = t_mm*10^-3;

density =(Ps-(ws^2 *Pd)/(wd^2))*(4/(ws^2*t*delD));
D0 = Dd - (Pd)/((wd^2*Ps)/(ws^2*delD)- Pd/(delD));
D0_mm = D0/10^-3;
end