function Sonetics_ExtScript

% Import user-entered variables from main script
RcvData = evalin('base','RcvData');
NumFrameStore = evalin('base','NumFrameStore');

FrameInfoList = evalin('base','FrameInfoList');  % Import existing list
hv2Sldr = get(findobj('Tag','hv2Sldr'),'Value');  % Get voltage set point
% hvSetValueSonetics = evalin('base','hvSetValueSonetics');
hv2Actual = evalin('base','extCapVoltage');  % Get actual voltage
push_total_duration_us = evalin('base','push_total_duration_us');

if evalin('base','exist(''CurrentFrame'',''var'')')
    CurrentFrame = evalin('base','CurrentFrame');
else
    CurrentFrame = 1;
end
hv2SetPoint = hv2Sldr;

if evalin('base','exist(''hv2ArraySetPoint'',''var'')')
     hv2SetPoint = evalin('base','hv2ArraySetPoint');
else
    hv2SetPoint = hv2Sldr;
end

% hv2SetPoint = 99;
% hv2SetPoint = hv2Sldr;

% hv2SetPoint = 57;
% Send Output Info to Screen
formatSpec = 'Capturing Frame %2.0f with Set/Actual = %3.1f V / %3.1f V\n';
fprintf(formatSpec,CurrentFrame,hv2SetPoint,hv2Actual);

FrameInfoList(CurrentFrame,1) = hv2SetPoint;
FrameInfoList(CurrentFrame,2) = hv2Actual;
FrameInfoList(CurrentFrame,3) = push_total_duration_us/1000; % Push Duration in ms

NumFramesValid = CurrentFrame;

if CurrentFrame < NumFrameStore
    CurrentFrame = CurrentFrame + 1;  
else
    CurrentFrame = 1;  % Reset frame counter if already recorded enough frames.
end

assignin('base','CurrentFrame', CurrentFrame);
assignin('base','NumFramesValid',NumFramesValid); % Last Recorded Frame
assignin('base','FrameInfoList',FrameInfoList)

% scrsz = get(0,'ScreenSize');
% ChanNum = 64;
% page = 1;
% Frame = 4;
% % for Frame = 1:NumFrameStore
%     figure(1111);
%     set(gcf,'OuterPosition',[2*scrsz(3)/3 scrsz(4)/2 scrsz(3)/3 scrsz(4)/2])
% %     imagesc(RcvData{1}(1:1024+1024*(page-1),:,Frame)); colorbar;
%         imagesc(RcvData{1}(:,:,Frame)); colorbar;
%      title(['Raw Receive Data from Frame ' num2str(Frame)]);
%     figure(1212);
%     set(gcf,'OuterPosition',[scrsz(3)/3 scrsz(4)/2 scrsz(3)/3 scrsz(4)/2])
%     plot(RcvData{1}(1:1024+1024*(page-1),ChanNum,Frame));
%     title(['Raw Receive Data from Frame ' num2str(Frame) '     Channel Number ' num2str(ChanNum)]);
%     pause(1);


return