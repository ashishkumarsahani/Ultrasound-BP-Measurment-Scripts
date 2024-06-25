function check_PushView_and_Voltage_Change()
    push_On_During_View = evalin('base', 'push_On_During_View');
    if(push_On_During_View ==0)
        [result, ~] = setTpcProfileHighVoltage(5,5);
    else
       [result, ~] = setTpcProfileHighVoltage(evalin('base', 'push_Viewer_Voltage'),5);
    end
end