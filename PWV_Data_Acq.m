%% Live push frames
Mcr_GuiHide = 1; %Control panel hide
Mcr_DisplayHide = 1; %Display window hide
extDisplay_On =1; %External display on

number_Of_Angles =1; %Currently this is designed for number_Of_Angles=1

if (number_Of_Angles > 1), dtheta = 0.5*(36*pi/180)/(number_Of_Angles-1); else dtheta = 0; end % set dtheta to range over +/- 18 degrees.
image_Pulse_TXnum = 1;
current_Voltage_Level_Index = 1;
viewer_Mode = 1;
voltage_Levels = PWV_Imaging_Voltage;

clear Media;
pt1;
Media.function = 'move_Points';

clear TW;
% Specify Transmit waveform structure.
TW(1).type = 'parametric';
TW(1).Parameters = [18,17,2,1];

clear TX;
TX(1).waveform = 1; % use 1st TW structure.
TX(1).focus = 0;
TX(1).Origin = [0, 0, 0];
TX(1).Apod =  ones(1,128);
TX(1).Steer = [0.0,0.0];
TX(1).Delay = computeTXDelays(TX(1));

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
Resource.RcvBuffer(1).rowsPerFrame = 2^nextpow2(2*round(ceil(2*(RF_Points_Per_Wavelength*(end_RF_Depth/wavelength_in_mm)))/2)); %range is set to double the target distance.
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = no_of_Snapshots; % minimum size is 1 frame.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).rowsPerFrame = PData(1).Size(1,1); % this is for greatest depth
Resource.InterBuffer(1).colsPerFrame = PData.Size(2);
Resource.InterBuffer(1).numFrames = no_of_Snapshots;  %We need only the IQ data from which we can pull out the RF
Resource.InterBuffer(1).pagesPerFrame = 1;
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = PData(1).Size(1,1);
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = 1;
Resource.ImageBuffer(1).pagesPerFrame = 1; 
Resource.DisplayWindow(1).pdelta = 1/10;
Resource.VDAS.dmaTimeout = 100;

clear RcvData;
clear ImgData;
clear IQData;
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
                        'callMediaFunc', 0),1,no_of_Snapshots);
                    
% - Set event specific Receive attributes.
rcv_Count =0;
for i = 1:no_of_Snapshots
        rcv_Count = rcv_Count+1;
        Receive(rcv_Count).Apod = ones(1,128);
        Receive(rcv_Count).startDepth = 0;
        Receive(rcv_Count).endDepth = end_RF_Depth/wavelength_in_mm;
        Receive(rcv_Count).TGC = 1; % Use the first TGC waveform defined above
        Receive(rcv_Count).mode = 0;
        Receive(rcv_Count).bufnum = 1;
        Receive(rcv_Count).framenum = i;
        Receive(rcv_Count).acqNum = 1;
        Receive(rcv_Count).samplesPerWave = RF_Points_Per_Wavelength;
        Receive(rcv_Count).InputFilter = [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494];
        Receive(rcv_Count).callMediaFunc = 1;
end

% Specify Recon structure arrays.
clear Recon;
Recon = repmat(struct('senscutoff', 0.6, ...
               'pdatanum', 1, ...
               'IntBufDest', [1,-1], ...  % auto-increment ImageBuffer each recon
               'ImgBufDest', [1,-1], ...  % auto-increment ImageBuffer each recon
               'newFrameTimeout', -1,...
               'RINums', 1), 1, no_of_Snapshots);

clear ReconInfo;
ReconInfo = repmat(struct('mode', 0, ...  % default accumulate IQ data.
                   'txnum', 1, ...
                   'rcvnum', 1, ...
                   'pagenum',1,...
                   'regionnum', 0), 1, no_of_Snapshots);

for j =1:no_of_Snapshots
    ReconInfo(j).mode = 0;
    ReconInfo(j).rcvnum = j;
    Recon(j).RINums = j;
    Recon(j).ImgBufDest = [1,1];
    Recon(j).IntBufDest = [1,j];
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
SeqControl(2).argument = 524287; % # Wait 100 ms

SeqControl(3).command = 'jump'; % jump back to start.
SeqControl(3).argument = 3;
SeqControl(4).command = 'returnToMatlab';
SeqControl(5).command = 'sync';
SeqControl(5).argument = 30e06; % Timeout

SeqControl(6).command = 'timeToNextAcq';
SeqControl(6).argument = PWV_Interframe_Time_us;

time_to_Next_Flash_Angle_us = 150; 
SeqControl(7).command = 'timeToNextAcq';
SeqControl(7).argument = time_to_Next_Flash_Angle_us;

SeqControl(8).command = 'triggerOut';

pressure_Time_List = [0:no_of_Snapshots-1]*PWV_Interframe_Time_us;
seq_Count = 9; 
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
Event(event_Count).process = 0; %Set voltage and move the voltage pointer to the next lower voltage
Event(event_Count).seqControl = 5;
event_Count = event_Count+1;

%%%%%Live image view%%%%%
for i=1:200
    Event(event_Count).info = 'Acquire the live image';
    Event(event_Count).tx = 1; % use 1st TX structure.
    Event(event_Count).rcv = 1; % use 1st Rcv structure.
    Event(event_Count).recon = 1; % no reconstruction.
    Event(event_Count).process = 7; % read voltage here
    Event(event_Count).seqControl = [seq_Count 2 4]; 
    event_Count = event_Count+1;
    SeqControl(seq_Count).command = 'transferToHost';
    seq_Count = seq_Count+1;  
end

%%%%%%%%%%%%%%%%%%%%%%%%%
%Sync hardware and software
Event(event_Count).info = 'Sync HW and SW';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; %Set voltage and move the voltage pointer to the next lower voltage
Event(event_Count).seqControl = 5;
event_Count = event_Count+1;

Event(event_Count).info = 'Start Time stamped pressure acquisition';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 5; % read pressure here
Event(event_Count).seqControl = [4]; %return to matlab
event_Count = event_Count+1;

%Sync hardware and software
Event(event_Count).info = 'Sync HW and SW';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; %Set voltage and move the voltage pointer to the next lower voltage
Event(event_Count).seqControl = [5];
event_Count = event_Count+1;

for i = 1:no_of_Snapshots
        Event(event_Count).info = 'Acquire the ref. image';
        Event(event_Count).tx = 1; % use 1st TX structure.
        Event(event_Count).rcv = i; % use 1st Rcv structure.
        Event(event_Count).recon = 0; % no reconstruction.
        Event(event_Count).process = 0; % 
        Event(event_Count).seqControl = [6 seq_Count]; 
        SeqControl(seq_Count).command = 'transferToHost';
        seq_Count = seq_Count+1; 
        event_Count = event_Count+1;
end
       
%Sync hardware and software
Event(event_Count).info = 'Sync HW and SW';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; %Set voltage and move the voltage pointer to the next lower voltage
Event(event_Count).seqControl = 5;
event_Count = event_Count+1;

Event(event_Count).info = 'Stop Pressure Acq';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 6; % 
Event(event_Count).seqControl = 4; % no processing
event_Count = event_Count+1;

for i = 1:no_of_Snapshots
    Event(event_Count).info = 'Reconstruction';
    Event(event_Count).tx = 0; % use 1st TX structure.
    Event(event_Count).rcv = 0; % use 1st Rcv structure.
    Event(event_Count).recon = i; % reconstruction.
    Event(event_Count).process = 7; % Show images
    Event(event_Count).seqControl = 4; % pause after image show
    event_Count = event_Count + 1;
end

Event(event_Count).info = 'Exit';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 4; % 
Event(event_Count).seqControl = 0; % no processing

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
Process(4).method = 'reconstruction_Finished';
Process(4).Parameters = {};

Process(5).classname = 'External';
Process(5).method = 'start_Time_Stamped_Pressure_Acq';
Process(5).Parameters = {};

Process(6).classname = 'External';
Process(6).method = 'stop_Time_Stamped_Pressure_Acq';
Process(6).Parameters = {};

Process(7).classname = 'Image';
Process(7).method = 'imageDisplay';
Process(7).Parameters = {'imgbufnum',1,...   % number of buffer to process.
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
                         'extDisplay',extDisplay_On};

% Save all the structures to a .mat file.
filename = 'PWV_Data_Acq.mat';
save(filename);
VSX

