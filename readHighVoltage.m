function readHighVoltage()
sim_Mode = evalin('base','Resource.Parameters.simulateMode');
if(sim_Mode == 1)
    return
end

[Result,extCapVoltage] = getHardwareProperty('TpcExtCapVoltage');
if ~strcmp(Result,'Success')
    error('VSX: Error from getHardwareProperty call to read push capacitor Voltage.');
else
    disp(['Current external voltage: ',num2str(extCapVoltage)]);
end
end