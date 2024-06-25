function stopSeqFor_ms()
    stop_Seq_ms = str2num(get(evalin('base', 'time_Between_Acq_in_Viewer_Mode_Text'),'String'));
    pause(stop_Seq_ms/1000);
end