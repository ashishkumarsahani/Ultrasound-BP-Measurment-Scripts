function setHighVoltage()
delay_Per_Voltage_Set = 2;
setVoltage = evalin('base','voltage_Levels(current_Voltage_Level_Index)');
current_Voltage_Level_Index = evalin('base','current_Voltage_Level_Index');
    
sim_Mode = evalin('base','Resource.Parameters.simulateMode');
if(sim_Mode == 1)
    evalin('base','voltage_Levels(current_Voltage_Level_Index) = voltage_Levels(current_Voltage_Level_Index) + rand(1);');
    viewer_Mode = evalin('base', 'viewer_Mode');
    if(viewer_Mode == 0 && evalin('base','length(voltage_Levels)>1'))
        assignin('base', 'current_Voltage_Level_Index', current_Voltage_Level_Index+1);
    end
    return
else
    pause(delay_Per_Voltage_Set); % Wait for tube to stabilize
end

[Result,extCapVoltage] = getHardwareProperty('TpcExtCapVoltage');
if ~strcmp(Result,'Success')
error('VSX: Error from getHardwareProperty call to read push capacitor Voltage.');
else
    disp(['Initial voltage is : ',num2str(extCapVoltage)]);
end

trackP5 = 5;
[result, ~] = setTpcProfileHighVoltage(setVoltage,trackP5);
if ~strcmpi(result, 'Success') && ~strcmpi(result, 'Hardware Not Open')
    % ERROR!  Failed to set high voltage.
    error('ERROR!  Failed to set Verasonics TPC high voltage for profile %d because \"%s\".', int8(trackP5), result);
    return;
else
    disp(['Current voltage set point is: ',num2str(setVoltage)]);
    i = 1;
    while(i<1000)
        [Result,extCapVoltage] = getHardwareProperty('TpcExtCapVoltage');
        if ~strcmp(Result,'Success')
            error('VSX: Error from getHardwareProperty call to read push capacitor Voltage.');
            return;
        else
            disp(['Current external voltage : ',num2str(extCapVoltage)]);
            if(extCapVoltage > 0.96*setVoltage && extCapVoltage<setVoltage)
                break;
            end
        end
        pause(0.1);
        i= i+1;
    end
end

viewer_Mode = evalin('base', 'viewer_Mode');
if(viewer_Mode == 0 && evalin('base','length(voltage_Levels)>1'))
    evalin('base',['voltage_Levels(current_Voltage_Level_Index) = ', num2str(extCapVoltage),';']);
    assignin('base', 'current_Voltage_Level_Index', current_Voltage_Level_Index+1);
end

end