function plot_dir (vX, vY)
scatter(vX,vY,'r');
hold on;
quiver(vX(1:end-1),vY(1:end-1),diff(vX),diff(vY),0);
end