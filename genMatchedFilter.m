function [aicFirstbreak] = genMatchedFilter(data)

% find approximate peak of the mean receive pulse
[~, peakN] = max( abs(data) );

% calculate AIC function of the mean receive pulse, prior to peak
aicFn = zeros([1, peakN], 'double');

for k = 2:peakN - 2
    aicFn(k)= k*log( var(data(1:k)) ) + (peakN - k - 1)*log( var(data(k + 1:peakN)) );
end

% sort the endpoints so they don't throw off our calculations
aicFn(1) = aicFn(2);
aicFn(end) = aicFn(end - 2); 
aicFn(end-1) = aicFn(end -2);

% obtain extremal values
aicMin = min(aicFn);
aicMax = max(aicFn);

% calculate Akaike weights
akaikeWeights = zeros([1, peakN], 'double');

akaikeWeights = exp( -(aicFn - aicMin)/2 );
akaikeNorm = sum(akaikeWeights);
akaikeWeights = akaikeWeights/akaikeNorm;

% estimate first break point with weighted AIC criterion
aicFirstbreak = round( sum( (1:peakN).*akaikeWeights ) );
end