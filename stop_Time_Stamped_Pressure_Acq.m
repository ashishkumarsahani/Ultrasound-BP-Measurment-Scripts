function stop_Time_Stamped_Pressure_Acq()
    [time_Stamps,data_Pts] = pressure_Reader(5);
    pressure_Pts = zeros(length(time_Stamps),1);
    for i=1:length(time_Stamps)
        pressure_Pts(i) = 51.7*typecast(uint8(data_Pts((i-1)*4+1:(i-1)*4+4)),'single');
    end
    pressure_Time_List = evalin('base', 'pressure_Time_List;');
    ping_Pressure = zeros(length(pressure_Time_List),1);
    for pT = 1:length(pressure_Time_List)
        ping_Time_Stamp_Index = find(time_Stamps>=pressure_Time_List(pT),1,'first');
        ping_Pressure(pT) = pressure_Pts(ping_Time_Stamp_Index);
    end
    ping_Pressure
    assignin('base','ping_Pressure_List',ping_Pressure);
end