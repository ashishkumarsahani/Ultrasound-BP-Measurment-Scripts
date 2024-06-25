%% A script to image a simulated line target
clear all;

Mcr_GuiHide = 1; %Control panel hide
Mcr_DisplayHide = 1; %Display window hide

RF_Points_Per_Wavelength = 4;
IQ_Points_Per_Wavelength = 10;

transducer_Frequency_in_Hz = 5000000;
PRF = 4500;

image_Pulse_TXnum = 1;
push_Pulse_TXnum = 2;

pressure_In_Tube = 70;
voltage_Levels = [50:-1:5];
current_Voltage_Level_Index = 1;
focal_Length = 73; %in wavelength

num_of_Frames_Per_Push_Cycle = 8;

num_of_Pulses_per_Push = 4;

%Specify the resource object
Resource.Parameters.numTransmit = 128;  % number of transmit channels.
Resource.Parameters.numRcvChannels = 128;  % number of receive channels.
Resource.Parameters.speedOfSound = 1540;
Resource.Parameters.simulateMode = 1;  % Run in simulation mode

%Specify the transducer object
Trans.name = 'L7-4';
Trans.frequency = transducer_Frequency_in_Hz/1000000;
Trans = computeTrans(Trans);
wavelength_in_mm = 1000*Resource.Parameters.speedOfSound/transducer_Frequency_in_Hz;

Point_Distance_in_mm = 20;
r = 8;
theta = [0:0.1:2*pi];
x_Arr = r*cos(theta);
z_Arr = r*sin(theta);
z_Arr = z_Arr - Point_Distance_in_mm/wavelength_in_mm;

for i = 1:length(theta)
    Media.MP(i,:) = [x_Arr(i),0, z_Arr(i),0.5];
end
Media.function = 'move_Points'

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

x = [1:128];
c = 10;
Apod_Gauss_Curve = exp(-((x-64.5).^2)./(2*c^2));

% Specify TX structure array.
TX(1).waveform = 1; % use 1st TW structure.
TX(1).focus = 0;
TX(1).Apod =  ones(1,Trans.numelements);
TX(1).Delay = computeTXDelays(TX(1));

TX(2).waveform = 2; % use 2nd TW structure.
TX(2).Origin = [0, 0, 0];
TX(2).focus = focal_Length;
TX(2).Apod =  ones(1,Trans.numelements);
TX(2).Apod(1:35) = 0;
TX(2).Apod(128-34:128) = 0;
TX(2).Delay = computeTXDelays(TX(2));

% Specify TGC Waveform structure.
TGC(1).CntrlPts = [500,590,650,710,770,830,890,950];
TGC(1).rangeMax = 200;
TGC(1).Waveform = computeTGCWaveform(TGC);

% Specify TPC structures.
TPC(1).name = '2D';
TPC(1).maxHighVoltage = 50;
TPC(5).name = 'Push';
TPC(5).maxHighVoltage = 50;

% Specify SFormat structure arrays.
SFormat(1).transducer = 'L7-4';     % 128 element linear array with 1.0 lambda spacing
SFormat(1).scanFormat = 'RLIN';     % rectangular linear array scan
SFormat(1).radius = 0;              % ROC for curved lin. or dist. to virt. apex
SFormat(1).theta = 0;
SFormat(1).numRays = 1;             % no. of Rays (1 for Flat Focus)
SFormat(1).FirstRayLoc = [0,0,0];   % x,y,z
SFormat(1).rayDelta = 128*Trans.spacing;  % spacing in radians(sector) or dist. between rays (wvlnghts)
SFormat(1).startDepth = 0;      % Acquisition start depth in wavelengths
SFormat(1).endDepth = 2*(Point_Distance_in_mm/wavelength_in_mm); % Acquisition end depth

PData(1).sFormat = 1;               % use first SFormat structure.
PData(1).pdeltaX = Trans.spacing;
PData(1).pdeltaZ = 1/IQ_Points_Per_Wavelength;
PData(1).Size(1,1) = ceil(10/(wavelength_in_mm*PData(1).pdeltaZ)); %10 mm space in z direction
PData(1).Size(1,2) = ceil(10/(wavelength_in_mm*PData(1).pdeltaX)); %10 mm space in x direction
PData(1).Size(1,3) = 1;                   % single image page
PData(1).Origin = [-ceil(5/wavelength_in_mm),0,focal_Length - ceil(5/wavelength_in_mm)]; % 2.5 mm off to the left of center and 2.5 mm off to the top of focal length 

% PData(1).Size(1,1) = ceil((SFormat(1).endDepth-SFormat(1).startDepth)/PData(1).pdeltaZ); % rows
% PData(1).Size(1,2) = ceil((Trans.numelements*Trans.spacing)/PData.pdeltaX);
% PData(1).Size(1,3) = 1;             % single image page
% PData(1).Origin = [-Trans.spacing*(Trans.numelements-1)/2,0,SFormat(1).startDepth]; % x,y,z of uppr lft crnr.

Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = 2^nextpow2(2*round(ceil(2*(RF_Points_Per_Wavelength*2*(Point_Distance_in_mm/wavelength_in_mm)))/2))* (num_of_Frames_Per_Push_Cycle); %range is set to double the target distance.
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

Resource.VDAS.dmaTimeout = 1;
Resource.DisplayWindow(1).Title = 'L7-4Flash';
Resource.DisplayWindow(1).pdelta = 0.3;
ScrnSize = get(0,'ScreenSize');
DwWidth = ceil(PData.Size(2)*PData.pdeltaX/Resource.DisplayWindow(1).pdelta);
DwHeight = ceil(PData.Size(1)*PData.pdeltaZ/Resource.DisplayWindow(1).pdelta);
Resource.DisplayWindow(1).Position = [250,(ScrnSize(4)-(DwHeight+150))/2, ...  % lower left corner position
                                      DwWidth, DwHeight];
Resource.DisplayWindow(1).ReferencePt = [PData.Origin(1),PData.Origin(3)];   % 2D imaging is in the X,Z plane
Resource.DisplayWindow(1).Colormap = gray(256);

% Specify Recon structure arrays.
Recon = repmat(struct('senscutoff', 0.6, ...
               'pdatanum', 1, ...
               'IntBufDest', [1,1], ...
               'ImgBufDest', [1,-1], ...  % auto-increment ImageBuffer each recon
               'RINums', 1), 1, num_of_Frames_Per_Push_Cycle*length(voltage_Levels));
           
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

Receive = repmat(struct('Apod', zeros(1,Trans.numelements), ...
                        'startDepth', SFormat.startDepth, ...
                        'endDepth', 2*Point_Distance_in_mm/wavelength_in_mm, ...
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
    Receive(i).endDepth = 2*Point_Distance_in_mm/wavelength_in_mm;
    Receive(i).TGC = 1; % Use the first TGC waveform defined above
    Receive(i).mode = 0;
    Receive(i).bufnum = 1;
    Receive(i).framenum = ceil(i/num_of_Frames_Per_Push_Cycle);
    Receive(i).acqNum = mod(i-1, num_of_Frames_Per_Push_Cycle) +1;
    Receive(i).samplesPerWave = RF_Points_Per_Wavelength;
    Receive(i).InputFilter = [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494];
    Receive(i).callMediaFunc =1;
end

% Specify SeqControl structure arrays.

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
SeqControl(2).argument = 5*10000; % # Wait 50 milliseconds 
SeqControl(3).command = 'jump'; % jump back to start.
SeqControl(3).argument = 3;
SeqControl(4).command = 'timeToNextAcq';  % time between frames
SeqControl(4).argument = 1000000*(1/PRF);  
SeqControl(5).command = 'timeToNextAcq';  % time between push and first frame
SeqControl(5).argument = 1000000*(1/PRF);  %1 seconds
SeqControl(6).command = 'returnToMatlab';
SeqControl(7).command = 'sync';
SeqControl(7).argument = 30E6; % Timeout

push_pulse_duration_us = (31*64)/(5*2);
time_us_between_push = 5; 
time_us_pushend2imagestart =  20;

SeqControl(8).command = 'timeToNextEB';
SeqControl(8).argument = max(push_pulse_duration_us + time_us_between_push + 8,...
                               time_us_between_push);
SeqControl(9).command = 'timeToNextAcq';
SeqControl(9).argument = push_pulse_duration_us + time_us_pushend2imagestart;   

seq_Count = 10; 
event_Count = 2;

Event(event_Count).info = 'Delay for Push Power Supply to Charge Up';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; 
Event(event_Count).seqControl = 2;
event_Count = event_Count+1;

for l = 1:length(voltage_Levels)
Event(event_Count).info = 'Set the voltage';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 3; %Set voltage and move the voltage pointer to the next voltage
Event(event_Count).seqControl = 2;
event_Count = event_Count+1;

%Sync hardware and software
Event(event_Count).info = 'Sync HW and SW';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; %Set voltage and move the voltage pointer to the next lower voltage
Event(event_Count).seqControl = 7;
event_Count = event_Count+1;

%%%%%%%Reference Image%%%%%%
Event(event_Count).info = 'Acquire the ref. image';
Event(event_Count).tx = image_Pulse_TXnum; % use 1st TX structure.
Event(event_Count).rcv = (l-1)*num_of_Frames_Per_Push_Cycle +1; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 4; % read voltage here
Event(event_Count).seqControl = 4; %Delay after this is only PRT or less
event_Count = event_Count+1;

%%%%%%%Push Pulses%%%%%%%%%%%
for i = 1:num_of_Pulses_per_Push
Event(event_Count).info = 'Push Pulse Delivery';
Event(event_Count).tx = push_Pulse_TXnum; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 2nd Rcv structure to see what exactly happens during the push burst
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % no processing
Event(event_Count).seqControl = 8; % Sequence element to give required delay after the push
event_Count = event_Count+1;
end
Event(event_Count-1).rcv = (l-1)*num_of_Frames_Per_Push_Cycle + 2;
Event(event_Count-1).seqControl = 9;

% Specify sequence events.
for i = 3:num_of_Frames_Per_Push_Cycle
Event(event_Count).info = ['RF Data frame ',num2str(i-3+1), 'after the push'];
Event(event_Count).tx = image_Pulse_TXnum; % use 1st TX structure.
Event(event_Count).rcv = (l-1)*num_of_Frames_Per_Push_Cycle+ i; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % no processing
Event(event_Count).seqControl = 4; % PRT delay
event_Count = event_Count + 1;
end
Event(event_Count-1).seqControl = 0;
Event(event_Count-1).seqControl = [seq_Count]; % PRT delay
SeqControl(seq_Count).command = 'transferToHost';
seq_Count = seq_Count+1;
end

for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)
    Event(event_Count).info = 'Reconstruction';
    Event(event_Count).tx = 0; % use 1st TX structure.
    Event(event_Count).rcv = 0; % use 1st Rcv structure.
    Event(event_Count).recon = i; % reconstruction.
    Event(event_Count).process = 2; % no processing
    Event(event_Count).seqControl = 0; % pause after image show

    event_Count = event_Count + 1;

    Event(event_Count).info = 'Return to matlab';
    Event(event_Count).tx = 0; % use 1st TX structure.
    Event(event_Count).rcv = 0; % use 1st Rcv structure.
    Event(event_Count).recon = 0; % reconstruction.
    Event(event_Count).process = 0; % no processing
    Event(event_Count).seqControl = 6; % no processing

    event_Count = event_Count + 1;
end
Event(event_Count-1).process = 6; % no processing


    
Process(1).classname = 'External';
Process(1).method = 'TestScript_Plot_Fun';
Process(1).Parameters = {'srcbuffer','receive',... % name of buffer to process.
'srcbufnum',1,...
'srcframenum',1,...
'dstbuffer','none'};

% Specify Process structure array.
pers = 40;
Process(2).classname = 'Image';
Process(2).method = 'imageDisplay';
Process(2).Parameters = {'imgbufnum',1,...   % number of buffer to process.
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

Process(3).classname = 'External';
Process(3).method = 'setHighVoltage';
Process(3).Parameters = {};

Process(4).classname = 'External';
Process(4).method = 'readHighVoltage';
Process(4).Parameters = {};

Process(5).classname = 'External';
Process(5).method = 'showRF';
Process(5).Parameters = {};

Process(6).classname = 'External';
Process(6).method = 'reconstruction_Finished';
Process(6).Parameters = {};

Process(7).classname = 'External';
Process(7).method = 'hide_VSXFig';
Process(7).Parameters = {};

%- Create UI controls for moving the point
pos1x = 170;
pos1y = 180;
UI(1).Control = {'Style','slider',... % create slider control
'Position',[pos1x,pos1y-30,120,30],... % position on UI
'Max',150,'Min',0,'Value',32,...
'SliderStep',[1/100 8/100],...
'Tag','y_Slider',...
'Callback',{@y_Slider_Callback}};

%- Create UI controls for changing the apodiztion sigma
pos2x = 170;
pos2y = 220;
UI(2).Control = {'Style','slider',... % create slider control
'Position',[pos2x,pos2y-30,120,30],... % position on UI
'Max',150,'Min',1,'Value',32,...
'SliderStep',[1/100 8/100],...
'Tag','apod_Slider',...
'Callback',{@apod_Slider_Callback}};


% Save all the structures to a .mat file.
filename = 'Test_Script1.mat';
save(filename);
VSX
Display_and_Measurement_Interface

