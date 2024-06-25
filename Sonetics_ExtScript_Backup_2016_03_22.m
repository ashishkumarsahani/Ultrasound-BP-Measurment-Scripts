function Sonetics_ExtScript


% Import user-entered variables from main script

NumFrameStore = evalin('base','NumFrameStore');
CurrentFrame = evalin('base','CurrentFrame');
FrameInfoList = evalin('base','FrameInfoList');  % Import existing list
hv2Set = get(findobj('Tag','hv2Sldr'),'Value');  % Get voltage set point
hvSetValueSonetics = evalin('base','hvSetValueSonetics');
hv2Actual = evalin('base','extCapVoltage');  % Get actual voltage
push_total_duration_us = evalin('base','push_total_duration_us');

if hvSetValueSonetics == 99;
    hv2Set = hv2Set;
else
    hv2Set = hvSetValueSonetics;
end


% Send Output Info to Screen
formatSpec = 'Capturing Frame %2.0f with Set/Actual = %3.1f V / %3.1f V\n';
fprintf(formatSpec,CurrentFrame,hv2Set,hv2Actual);

FrameInfoList(CurrentFrame,1) = hv2Set;
FrameInfoList(CurrentFrame,2) = hv2Actual;
FrameInfoList(CurrentFrame,3) = push_total_duration_us/1000; % Push Duration in ms


if CurrentFrame < NumFrameStore
    NumFramesValid = CurrentFrame;
    CurrentFrame = CurrentFrame + 1;
else
    NumFramesValid = CurrentFrame;
    CurrentFrame = 1;
end

assignin('base','CurrentFrame', CurrentFrame);
assignin('base','NumFramesValid',NumFramesValid); % Last Recorded Frame
assignin('base','FrameInfoList',FrameInfoList)


return