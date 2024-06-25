function [RF_Arr] = demod_IQ(IQ_Arr)
real_Arr = real(IQ_Arr);
imag_Arr = imag(IQ_Arr);

theta_Arr = atan(imag_Arr./real_Arr);
theta_Arr(isnan(theta_Arr)) = 0 ;
RF_Arr = real_Arr./(cos(theta_Arr));
end