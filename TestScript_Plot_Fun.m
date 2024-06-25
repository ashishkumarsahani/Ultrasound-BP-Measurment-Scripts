function TestScript_Plot_Fun(RData)
persistent myHandle

if isempty(myHandle)||~ishandle(myHandle)
myHandle = figure;
end
figure(myHandle);
imagesc(RData);
colormap('jet')
drawnow
return