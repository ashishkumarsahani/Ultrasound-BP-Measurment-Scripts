function [RF_Arr] = IQtoRF(IQ_Arr)
    IQ_Arr(2:2:end,:) = -IQ_Arr(2:2:end,:);
    real_Arr = real(IQ_Arr);
    imag_Arr = imag(IQ_Arr);
    S = size(real_Arr);
    RF_Arr = zeros(S(1)*2,S(2));

    for i = 1:S(2)
        IR = interp(real_Arr(:,i),2);
        II = interp(imag_Arr(:,i),2);
        
        RF_Arr((1:4:2*S(1)),i) = IR(1:4:2*S(1));
        RF_Arr((2:4:2*S(1)),i) = II(2:4:2*S(1));
        RF_Arr((3:4:2*S(1)),i) = -IR(3:4:2*S(1));
        RF_Arr((4:4:2*S(1)),i) = -II(4:4:2*S(1));
    end
end