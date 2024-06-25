function [ stress ] = calculateLammeStressForTube(internal_Pressure, external_Pressure, inner_Radius, outer_Radius, radius_Of_Pressure)
Pi = internal_Pressure;
Po = external_Pressure;
ri = inner_Radius;
ro = outer_Radius;
r = radius_Of_Pressure;

stress = (((ri.^2)*Pi - (ro.^2)*Po)./(ro.^2 - ri.^2)) - (((Pi-Po).*(ri.*ro).^2)./((ro.^2 - ri.^2).*r.^2));
end

