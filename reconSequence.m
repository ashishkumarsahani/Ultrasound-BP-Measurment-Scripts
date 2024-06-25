%% A script to image a simulated line target
Mcr_GuiHide = 1; %Control panel hide
Mcr_DisplayHide = 1; %Display window hide
image_Pulse_TXnum = 1;

if (number_Of_Angles > 1), dtheta = 0.5*(36*pi/180)/(number_Of_Angles-1); else dtheta = 0; end % set dtheta to range over +/- 18 degrees.

clear TX;
% - Set event specific TX attributes.
if fix(number_Of_Angles/2) == number_Of_Angles/2       % if number_Of_Angles even
    startAngle = (-(fix(number_Of_Angles/2) - 1) - 0.5)*dtheta;
else
    startAngle = -fix(number_Of_Angles/2)*dtheta;
end
for n = 1:number_Of_Angles   % number_Of_Angles transmit events
    TX(n).waveform = 1; % use 1st TW structure.
    TX(n).focus = 0;
    TX(n).Origin = [0, 0, 0];
    TX(n).Apod =  ones(1,Trans.numelements);
    TX(n).Steer = [(startAngle+(n-1)*dtheta),0.0];
    TX(n).Delay = computeTXDelays(TX(n));
end

push_TX_Num = number_Of_Angles+1;
TX(push_TX_Num).waveform = 2; % use 2nd TW structure.
TX(push_TX_Num).Origin = [focal_X, 0, 0];
central_Element = find(Trans.ElementPos >= focal_X, 1, 'first');
TX(push_TX_Num).focus = focal_Length;
TX(push_TX_Num).Apod =  zeros(1,Trans.numelements);
TX(push_TX_Num).Apod(central_Element-32:central_Element+32) = 1;
TX(push_TX_Num).Steer = [0 0];
TX(push_TX_Num).Delay = computeTXDelays(TX(push_TX_Num));


Resource.VDAS.dmaTimeout = 1*number_Of_Angles;

clear TW;
% Specify Transmit waveform structure.
TW(1).type = 'parametric';
TW(1).Parameters = [18,17,2,1];

% Specify the push pulse
TW(2).type = 'parametric';
if(Resource.Parameters.simulateMode ==1)
    TW(2).Parameters = [18,17,3,1];
else
    TW(2).Parameters = [18,17,31,1];
end
TW(2).extendBL = 1;

clear Event;
clear DMAControl;

event_Count=1;
currentFrame = 0;
for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)
    if(i~=2)
        Event(event_Count).info = 'Reconstruction';
        Event(event_Count).tx = 0; % use 1st TX structure.
        Event(event_Count).rcv = 0; % use 1st Rcv structure.
        Event(event_Count).recon = i; % reconstruction.
        Event(event_Count).process = 6+i; % Show images
        Event(event_Count).seqControl = 0; % pause after image show

        event_Count = event_Count + 1;

        Event(event_Count).info = 'Return to matlab';
        Event(event_Count).tx = 0; % use 1st TX structure.
        Event(event_Count).rcv = 0; % use 1st Rcv structure.
        Event(event_Count).recon = 0; % reconstruction.
        Event(event_Count).process = 4; % display image
        Event(event_Count).seqControl = 6; % no processing

        event_Count = event_Count + 1;
    end
end
Event(event_Count-1).process = 5;
 
% Specify Process structure array.
pers = 40;
Process(1).classname = 'Image';
Process(1).method = 'imageDisplay';
Process(1).Parameters = {'imgbufnum',1,...   % number of buffer to process.
                         'framenum',1,...   % (-1 => lastFrame)
                         'pdatanum',1,...    % number of PData structure to use
                         'norm',1,...        % normalization method(1 means fixed)
                         'pgain',1.0,...            % pgain is image processing gain
                         'persistMethod','simple',...
                         'persistLevel',pers,...
                         'interp',1,...      % method of interpolation (1=4pt interp)
                         'compression',0.5,...      % X^0.5 normalized to output word size
                         'reject',5,...      % reject level 
                         'mappingMode','full',...
                         'display',1,...      % display image after processing
                         'displayWindow',1,...
                         'extDisplay',1};

Process(2).classname = 'External';
Process(2).method = 'setHighVoltage';
Process(2).Parameters = {};

Process(3).classname = 'External';
Process(3).method = 'readHighVoltage';
Process(3).Parameters = {};

Process(4).classname = 'External';
Process(4).method = 'reset_VDAS_Timeout';
Process(4).Parameters = {};

Process(5).classname = 'External';
Process(5).method = 'reconstruction_Finished';
Process(5).Parameters = {};

Process(6).classname = 'External';
Process(6).method = 'getReadytoFocus';
Process(6).Parameters = {};

frame_Count = 1;
for i = 7:7+num_of_Frames_Per_Push_Cycle*length(voltage_Levels) - 1
    Process(i).classname = 'Image';
    Process(i).method = 'imageDisplay';
    Process(i).Parameters = {'imgbufnum',1,...   % number of buffer to process.
                             'framenum',frame_Count,...   % (-1 => lastFrame)
                             'pdatanum',1,...    % number of PData structure to use
                             'norm',1,...        % normalization method(1 means fixed)
                             'pgain',1.0,...            % pgain is image processing gain
                             'persistMethod','simple',...
                             'persistLevel',pers,...
                             'interp',1,...      % method of interpolation (1=4pt interp)
                             'compression',0.5,...      % X^0.5 normalized to output word size
                             'reject',5,...      % reject level 
                             'mappingMode','full',...
                             'display',1,...      % display image after processing
                             'displayWindow',1,...
                             'extDisplay',1};
   frame_Count = frame_Count+1;
end
% Save all the structures to a .mat file.
filename = 'reconSequenceMat.mat';
save(filename);
VSX

