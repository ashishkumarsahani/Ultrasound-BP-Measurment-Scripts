%% Live push frames
Mcr_GuiHide = 1; %Control panel hide
Mcr_DisplayHide = 1; %Display window hide

number_Of_Angles =5;
if (push_On_During_View ==1)
    number_Of_Angles=1;
end

if (number_Of_Angles > 1), dtheta = 0.5*(36*pi/180)/(number_Of_Angles-1); else dtheta = 0; end % set dtheta to range over +/- 18 degrees.

timing_List_in_us = 0; 
push_Timing_Start_End = [0 0];
image_Pulse_TXnum = 1;
push_Pulse_TXnum = 2;
current_Voltage_Level_Index = 1;
reset_Phantom =1;

viewer_Mode = 1;
voltage_Levels = push_Viewer_Voltage;
num_of_Frames_Per_Push_Cycle = 2;
PRF = 1000; %Time between reference frame and and push pulse


clear Media;
pt1;
Media.function = 'move_Points';

clear TW;
% Specify Transmit waveform structure.
TW(1).type = 'parametric';
TW(1).Parameters = [18,17,2,1];

% Specify the push pulse
TW(2).type = 'parametric';
if(Resource.Parameters.simulateMode ==1)
    TW(2).Parameters = [18,17,2,1];
else
    TW(2).Parameters = [18,17,31,1];
end
TW(2).extendBL = 1;


clear TX;
% Specify TX structure array.
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

if(number_Of_Angles ==1)
    TX(1).Steer = [0.0,0.0];
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

% Specify TGC Waveform structure.
clear TGC
TGC(1).CntrlPts = [500,590,650,710,770,830,890,950];
TGC(1).rangeMax = 100;
TGC(1).Waveform = computeTGCWaveform(TGC);
if(TGC_On ==0)
    TGC(1).Waveform = (TGC(1).Waveform*0 +0.001); %Remove TGC
end

% Specify TPC structures.
clear TPC;
TPC(1).name = '2D';
TPC(1).maxHighVoltage = 100;
TPC(1).highVoltageLimit = 100;
TPC(5).name = 'Push';
TPC(5).maxHighVoltage = 100;
TPC(5).highVoltageLimit = 100;

% Specify SFormat structure arrays.
clear SFormat;
SFormat(1).transducer = 'L7-4';     % 128 element linear array with 1.0 lambda spacing
SFormat(1).scanFormat = 'RLIN';     % rectangular linear array scan
SFormat(1).radius = 0;              % ROC for curved lin. or dist. to virt. apex
SFormat(1).theta = 0;
SFormat(1).numRays = 1;             % no. of Rays (1 for Flat Focus)
SFormat(1).FirstRayLoc = [0,0,0];   % x,y,z
SFormat(1).rayDelta = 128*Trans.spacing;  % spacing in radians(sector) or dist. between rays (wvlnghts)
SFormat(1).startDepth = 0;      % Acquisition start depth in wavelengths
SFormat(1).endDepth = end_RF_Depth/wavelength_in_mm; % Acquisition end depth

Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = number_Of_Angles*2^nextpow2(2*round(ceil(2*(RF_Points_Per_Wavelength*(end_RF_Depth/wavelength_in_mm)))/2))* (num_of_Frames_Per_Push_Cycle); %range is set to double the target distance.
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = length(voltage_Levels); % minimum size is 1 frame.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).rowsPerFrame = PData(1).Size(1,1); % this is for greatest depth
Resource.InterBuffer(1).colsPerFrame = PData.Size(2);
Resource.InterBuffer(1).numFrames = num_of_Frames_Per_Push_Cycle*length(voltage_Levels);  % one intermediate buffer needed.
Resource.InterBuffer(1).pagesPerFrame = 1;
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = PData(1).Size(1,1);
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = num_of_Frames_Per_Push_Cycle*length(voltage_Levels);
Resource.ImageBuffer(1).pagesPerFrame = 1; 

Resource.VDAS.dmaTimeout = 1000*number_Of_Angles;
Resource.DisplayWindow(1).Title = 'L7-4Flash';
Resource.DisplayWindow(1).pdelta = 1/10;
ScrnSize = get(0,'ScreenSize');
DwWidth = ceil(PData.Size(2)*PData.pdeltaX/Resource.DisplayWindow(1).pdelta);
DwHeight = ceil(PData.Size(1)*PData.pdeltaZ/Resource.DisplayWindow(1).pdelta);
Resource.DisplayWindow(1).Position = [250,(ScrnSize(4)-(DwHeight+150))/2, ...  % lower left corner position
                                      DwWidth, DwHeight];
Resource.DisplayWindow(1).ReferencePt = [PData.Origin(1),PData.Origin(3)];  % 2D imaging is in the X,Z plane
Resource.DisplayWindow(1).Colormap = gray(256);

clear RcvData;
clear ImgData;
clear IQData;

% Specify Recon structure arrays.
clear Recon;
Recon = repmat(struct('senscutoff', 0.6, ...
               'pdatanum', 1, ...
               'IntBufDest', [1,1], ...
               'ImgBufDest', [1,-1], ...  % auto-increment ImageBuffer each recon
               'newFrameTimeout', -1,...
               'RINums', (1:number_Of_Angles)'), 1, num_of_Frames_Per_Push_Cycle*length(voltage_Levels));

clear ReconInfo;
ReconInfo = repmat(struct('mode', 4, ...  % default accumulate IQ data.
                   'txnum', image_Pulse_TXnum, ...
                   'rcvnum', 1, ...
                   'pagenum',1,...
                   'regionnum', 0), 1, number_Of_Angles*num_of_Frames_Per_Push_Cycle*length(voltage_Levels));

% - Set event specific Recon attributes.
for i = 1:number_Of_Angles*num_of_Frames_Per_Push_Cycle*length(voltage_Levels)
    if(number_Of_Angles ==1)
        ReconInfo(i).mode = 0;
    elseif(mod(i-1,number_Of_Angles) ==0)
        ReconInfo(i).mode = 3; %replace IQ data
    elseif(mod(i,number_Of_Angles) ==0)
        ReconInfo(i).mode = 5; %Detect
    else
        ReconInfo(i).mode = 4; %Accumulate
    end
    ReconInfo(i).rcvnum = i;
    ReconInfo(i).pagenum = 1;
    ReconInfo(i).txnum = mod(i-1,number_Of_Angles)+1;
end

for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)
    Recon(i).ImgBufDest = [1,i];
    Recon(i).IntBufDest = [1,i];
    Recon(i).RINums = number_Of_Angles*(i-1) + (1:number_Of_Angles)';
end

clear Receive;
Receive = repmat(struct('Apod', zeros(1,Trans.numelements), ...
                        'startDepth', SFormat.startDepth, ...
                        'endDepth', end_RF_Depth/wavelength_in_mm, ...
                        'TGC', 1, ...
                        'bufnum', 1, ...
                        'framenum', 1, ...
                        'acqNum', 1, ...
                        'samplesPerWave', 4, ...
                        'mode', 0, ...
                        'InputFilter',[0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494], ...
                        'callMediaFunc', 0),1,num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*number_Of_Angles);
                    
% - Set event specific Receive attributes.
for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*number_Of_Angles
    Receive(i).Apod = ones(1, 128);
    Receive(i).startDepth = 0;
    Receive(i).endDepth = end_RF_Depth/wavelength_in_mm;
    Receive(i).TGC = 1; % Use the first TGC waveform defined above
    Receive(i).mode = 0;
    Receive(i).bufnum = 1;
    Receive(i).framenum = ceil(i/(number_Of_Angles*num_of_Frames_Per_Push_Cycle));
    Receive(i).acqNum = mod(i-1, number_Of_Angles*num_of_Frames_Per_Push_Cycle) +1;
    Receive(i).samplesPerWave = RF_Points_Per_Wavelength;
    Receive(i).InputFilter = [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494];
    Receive(i).callMediaFunc = 1;
end


% Specify SeqControl structure arrays.
clear SeqControl;
clear Event;
clear Process;
clear DMAControl;

SeqControl(1).command = 'setTPCProfile';
SeqControl(1).condition = 'immediate';
SeqControl(1).argument = 5;
Event(1).info = 'Switch to Push Power Supply';
Event(1).tx = 0;   
Event(1).rcv = 0;   
Event(1).recon = 0;      % no reconstruction.
Event(1).process = 0;    % close the display windows
Event(1).seqControl = 1; % 

number_Of_Noops_Required =1;
if(time_Between_Acq_in_Viewer_Mode_Text>104)
    number_Of_Noops_Required = time_Between_Acq_in_Viewer_Mode_Text/104;
    SeqControl(2).command = 'noop';
    SeqControl(2).argument = 524287; % # Wait 100 ms
else
    SeqControl(2).command = 'noop';
    SeqControl(2).argument = round(time_Between_Acq_in_Viewer_Mode_Text*524287/104); % # Wait 100 ms
end

SeqControl(3).command = 'jump'; % jump back to start.
SeqControl(3).argument = 3;
SeqControl(4).command = 'timeToNextAcq';  % time between flash angles
interFrameTiming = 100000; %100 ms delay between two push seq
SeqControl(4).argument = interFrameTiming;  
SeqControl(5).command = 'timeToNextAcq';  % time between push and first frame
SeqControl(5).argument = interFrameTiming;  %1 seconds
SeqControl(6).command = 'returnToMatlab';
SeqControl(7).command = 'sync';
SeqControl(7).argument = 30E6; % Timeout

push_pulse_duration_us = (31*64)/(5*2);
time_us_between_push = 10; 
time_us_pushend2imagestart =  150;

SeqControl(8).command = 'timeToNextEB';
SeqControl(8).argument = max(push_pulse_duration_us + time_us_between_push,time_us_between_push);
push_Timing_Start_End(1) = interFrameTiming;
timing_List_in_us(2) = interFrameTiming + max(push_pulse_duration_us + time_us_between_push + 8,time_us_between_push)*(num_of_Pulses_per_Push-1);
SeqControl(9).command = 'timeToNextAcq';
SeqControl(9).argument = push_pulse_duration_us + time_us_pushend2imagestart;   

SeqControl(10).command = 'timeToNextAcq';
time_to_Next_Flash_Angle_us = 150;
SeqControl(10).argument = time_to_Next_Flash_Angle_us;  

push_Timing_Start_End(2) = timing_List_in_us(2) + push_pulse_duration_us;
timing_List_in_us(3) = timing_List_in_us(2) + push_pulse_duration_us + time_us_pushend2imagestart; 

if(num_of_Frames_Per_Push_Cycle> 3)
    for i = 4:num_of_Frames_Per_Push_Cycle
        timing_List_in_us(i) = timing_List_in_us(i-1) + time_to_Next_Flash_Angle_us*number_Of_Angles;
    end
end
seq_Count = 11; 
event_Count = 2;

Event(event_Count).info = 'Delay for Push Power Supply to Charge Up';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; 
Event(event_Count).seqControl = 2;
event_Count = event_Count+1;

Event(event_Count).info = 'Set the voltage';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 2; %Set voltage and move the voltage pointer to the next voltage
Event(event_Count).seqControl = 2;
event_Count = event_Count+1;

%Sync hardware and software
Event(event_Count).info = 'Sync HW and SW';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; 
Event(event_Count).seqControl = 7;
event_Count = event_Count+1;

%%%%%%%Reference Image%%%%%%
jump_Back_Pos = event_Count;
for image_Pulse_Num = 1:number_Of_Angles
    Event(event_Count).info = 'Acquire the ref. image';
    Event(event_Count).tx = image_Pulse_Num; % use 1st TX structure.
    Event(event_Count).rcv = image_Pulse_Num; % use 1st Rcv structure.
    Event(event_Count).recon = 0; % no reconstruction.
    Event(event_Count).process = 0; % read voltage here
    Event(event_Count).seqControl = 0; %Flash angles delay
    event_Count = event_Count+1;
end

if(push_On_During_View ==1)
    for i = 1:num_of_Pulses_per_Push
        Event(event_Count).info = 'Push Pulse Delivery';
        Event(event_Count).tx = push_TX_Num;
        Event(event_Count).rcv = 0; % use 2nd Rcv structure to see what exactly happens during the push burst
        Event(event_Count).recon = 0; % no reconstruction.
        Event(event_Count).process = 0; % no processing
        Event(event_Count).seqControl = 8;
        event_Count = event_Count+1;
    end
    Event(event_Count-1).seqControl = 9;
    
    Event(event_Count).info = ['RF Data frame after the push'];
    Event(event_Count).tx = image_Pulse_Num; % use 1st TX structure.
    Event(event_Count).rcv = 2; % use 1st Rcv structure.
    Event(event_Count).recon = 0; % no reconstruction.
    Event(event_Count).process = 0; % no processing
    Event(event_Count).seqControl = 0;
    event_Count = event_Count+1;
end
Event(event_Count).info = 'Transfer to host';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % read voltage here
Event(event_Count).seqControl = seq_Count; %Flash angles delay
event_Count = event_Count+1;
SeqControl(seq_Count).command = 'transferToHost';
seq_Count = seq_Count+1;    

Event(event_Count).info = 'Recon ref image';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 1; % no reconstruction.
Event(event_Count).process = 0; % read voltage here
Event(event_Count).seqControl = 0; %Flash angles delay
event_Count = event_Count+1;

if(switch_Between_Ref_Tracking ==1 || push_On_During_View ==0) %Show reference image
    Event(event_Count-1).process = 7;
end

if(push_On_During_View ==1)
    Event(event_Count).info = 'Recon the post push image';
    Event(event_Count).tx = 0; % use 1st TX structure.
    Event(event_Count).rcv = 0; % use 1st Rcv structure.
    Event(event_Count).recon = 2; % no reconstruction.
    Event(event_Count).process = 8; % read voltage here
    Event(event_Count).seqControl = 0; %Flash angles delay
    event_Count = event_Count+1;
end

Event(event_Count).info = 'Return to matlab';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 0; % display image
Event(event_Count).seqControl = 6; % no processing
event_Count = event_Count + 1;

for n = 1:number_Of_Noops_Required
    Event(event_Count).info = 'Noop';
    Event(event_Count).tx = 0; % use 1st TX structure.
    Event(event_Count).rcv = 0; % use 1st Rcv structure.
    Event(event_Count).recon = 0; % reconstruction.
    Event(event_Count).process = 0; % display image
    Event(event_Count).seqControl = [2]; % no processing
    event_Count = event_Count + 1;
end

Event(event_Count).info = 'Jump back';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 0; % display image
Event(event_Count).seqControl = [seq_Count]; % no processing
event_Count = event_Count + 1;
SeqControl(seq_Count).command = 'jump';
SeqControl(seq_Count).argument = jump_Back_Pos;

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
Process(4).method = 'stopSeqFor_ms';
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
filename = 'livePushView.mat';
save(filename);
VSX

