%% Live push frames
Mcr_GuiHide = 1; %Control panel hide
Mcr_DisplayHide = 1; %Display window hide

timing_List_in_us = 0; 
push_Timing_Start_End = [0 0];
image_Pulse_TXnum = 1;
push_Pulse_TXnum = 2;
current_Voltage_Level_Index = 1;

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
    TW(2).Parameters = [18,17,3,1];
else
    TW(2).Parameters = [18,17,31,1];
end
TW(2).extendBL = 1;


clear TX;
% Specify TX structure array.
TX(1).waveform = 1; % use 1st TW structure.
TX(1).focus = 0;
TX(1).Apod =  ones(1,Trans.numelements);
TX(1).Delay = computeTXDelays(TX(1));

TX(2).waveform = 2; % use 2nd TW structure.
TX(2).Origin = [focal_X, 0, 0];
central_Element = find(Trans.ElementPos >= focal_X, 1, 'first');
TX(2).focus = focal_Length;
TX(2).Apod =  zeros(1,Trans.numelements);
TX(2).Apod(central_Element-32:central_Element+32) = 1;
TX(2).Delay = computeTXDelays(TX(2));

% Specify TGC Waveform structure.
clear TGC
TGC(1).CntrlPts = [500,590,650,710,770,830,890,950];
TGC(1).rangeMax = 200;
TGC(1).Waveform = computeTGCWaveform(TGC);
TGC(1).Waveform = (TGC(1).Waveform*0 +1); %Remove TGC

% Specify TPC structures.
clear TPC;
TPC(1).name = '2D';
TPC(1).maxHighVoltage = 50;
TPC(5).name = 'Push';
TPC(5).maxHighVoltage = 50;

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
Resource.RcvBuffer(1).rowsPerFrame = 2^nextpow2(2*round(ceil(2*(RF_Points_Per_Wavelength*(end_RF_Depth/wavelength_in_mm)))/2))* (num_of_Frames_Per_Push_Cycle); %range is set to double the target distance.
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

Resource.VDAS.dmaTimeout = 1000;
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
               'RINums', 1), 1, num_of_Frames_Per_Push_Cycle*length(voltage_Levels));

clear ReconInfo;
ReconInfo = repmat(struct('mode', 0, ...  % replace IQ data.
                   'txnum', image_Pulse_TXnum, ...
                   'rcvnum', 1, ...
                   'pagenum',1,...
                   'regionnum', 0), 1, num_of_Frames_Per_Push_Cycle*length(voltage_Levels));

% - Set event specific Recon attributes.
for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)
    Recon(i).ImgBufDest = [1,i];
    Recon(i).IntBufDest = [1,i];
    Recon(i).RINums = i;
    ReconInfo(i).rcvnum = i;
    ReconInfo(i).pagenum = 1;
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
                        'callMediaFunc', 0),1,num_of_Frames_Per_Push_Cycle);
                    
% - Set event specific Receive attributes.
for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)
    Receive(i).Apod = ones(1, 128);
    Receive(i).startDepth = 0;
    Receive(i).endDepth = end_RF_Depth/wavelength_in_mm;
    Receive(i).TGC = 1; % Use the first TGC waveform defined above
    Receive(i).mode = 0;
    Receive(i).bufnum = 1;
    Receive(i).framenum = ceil(i/2);
    Receive(i).acqNum = mod(i-1, num_of_Frames_Per_Push_Cycle) +1;
    Receive(i).samplesPerWave = RF_Points_Per_Wavelength;
    Receive(i).InputFilter = [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494];
    Receive(i).callMediaFunc =1;
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

SeqControl(2).command = 'noop';
SeqControl(2).argument = 5*50000; % # value*200nsec
SeqControl(3).command = 'jump'; % jump back to start.
SeqControl(3).argument = 3;
SeqControl(4).command = 'timeToNextAcq';  % time between frames
interFrameTiming = 1000000*(1/PRF);
SeqControl(4).argument = interFrameTiming;  
SeqControl(5).command = 'timeToNextAcq';  % time between push and first frame
SeqControl(5).argument = interFrameTiming;  %1 seconds
SeqControl(6).command = 'returnToMatlab';
SeqControl(7).command = 'sync';
SeqControl(7).argument = 30E6; % Timeout

push_pulse_duration_us = (31*64)/(5*2);
time_us_between_push = 5; 
time_us_pushend2imagestart =  40;

SeqControl(8).command = 'timeToNextEB';
SeqControl(8).argument = max(push_pulse_duration_us + time_us_between_push + 8,time_us_between_push);
push_Timing_Start_End(1) = interFrameTiming;
timing_List_in_us(2) = interFrameTiming + max(push_pulse_duration_us + time_us_between_push + 8,time_us_between_push)*(num_of_Pulses_per_Push-1);
SeqControl(9).command = 'timeToNextAcq';
SeqControl(9).argument = push_pulse_duration_us + time_us_pushend2imagestart;   

push_Timing_Start_End(2) = timing_List_in_us(2) + push_pulse_duration_us;
timing_List_in_us(3) = timing_List_in_us(2) + push_pulse_duration_us + time_us_pushend2imagestart; 

if(num_of_Frames_Per_Push_Cycle> 3)
    for i = 4:num_of_Frames_Per_Push_Cycle
        timing_List_in_us(i) = timing_List_in_us(i-1) + 1000000*(1/PRF);
    end
end
seq_Count = 10; 
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
Event(event_Count).info = 'Acquire the ref. image';
Event(event_Count).tx = image_Pulse_TXnum; % use 1st TX structure.
Event(event_Count).rcv = 1; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % read voltage here
Event(event_Count).seqControl = 4; %Delay after this is only PRT or less
event_Count = event_Count+1;

%%%%%%%Push Pulses%%%%%%%%%%%
for i = 1:num_of_Pulses_per_Push
Event(event_Count).info = 'Push Pulse Delivery';
if(push_On_During_View ==0)
    Event(event_Count).tx = image_Pulse_TXnum;
else
    Event(event_Count).tx = push_Pulse_TXnum; % use 1st TX structure.
end
Event(event_Count).rcv = 0; % use 2nd Rcv structure to see what exactly happens during the push burst
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % no processing
if(push_On_During_View ==0)
    Event(event_Count).seqControl = 9; % Sequence element to give required delay after the push
else
    Event(event_Count).seqControl = 8;
end
event_Count = event_Count+1;
end

Event(event_Count-1).seqControl = 9;


% The first tracking frame

Event(event_Count).info = ['RF Data frame after the push'];
Event(event_Count).tx = image_Pulse_TXnum; % use 1st TX structure.
Event(event_Count).rcv = 2; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % no processing
Event(event_Count).seqControl = 4; % PRT delay
event_Count = event_Count + 1;

Event(event_Count).info = ['Check viewer mode change'];
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 4; % no processing
Event(event_Count).seqControl = 0; % PRT delay
event_Count = event_Count + 1;

Event(event_Count).info = ['Transfer to Host'];
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % no processing
Event(event_Count).seqControl = seq_Count; % PRT delay
event_Count = event_Count + 1;

SeqControl(seq_Count).command = 'transferToHost';
SeqControl(seq_Count).condition = 'waitForProcessing';
SeqControl(seq_Count).argument = seq_Count;
seq_Count = seq_Count+1;

SeqControl(seq_Count).command = 'waitForTransferComplete';
SeqControl(seq_Count).argument = seq_Count-1;
seq_Count = seq_Count+1;

SeqControl(seq_Count).command = 'markTransferProcessed';
SeqControl(seq_Count).argument = seq_Count-2;
seq_Count = seq_Count+1;

currentFrame = 0;
for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)
    Event(event_Count).info = 'Reconstruction';
    Event(event_Count).tx = 0; % use 1st TX structure.
    Event(event_Count).rcv = 0; % use 1st Rcv structure.
    Event(event_Count).recon = i; % reconstruction.
    Event(event_Count).process = 6+i; % change frame number
    Event(event_Count).seqControl = 0; % pause after image show
    
    if(i ==1)
        Event(event_Count).seqControl = [seq_Count-2 seq_Count-1];
        if(switch_Between_Ref_Tracking ==0)
            Event(event_Count).process = 0; %Don't show the reference frame
        end
    end
    event_Count = event_Count + 1;
    
    Event(event_Count).info = 'Return to matlab';
    Event(event_Count).tx = 0; % use 1st TX structure.
    Event(event_Count).rcv = 0; % use 1st Rcv structure.
    Event(event_Count).recon = 0; % reconstruction.
    Event(event_Count).process = 0; % display image
    Event(event_Count).seqControl = 6; % no processing
    
    event_Count = event_Count + 1;
end

Event(event_Count).info = 'Jump back';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 0; % display image
Event(event_Count).seqControl = [2 seq_Count]; % no processing
event_Count = event_Count + 1;

SeqControl(seq_Count).command = 'jump';
SeqControl(seq_Count).argument = 5;
    

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

