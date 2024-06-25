%% A script to image a simulated line target

clear all;

points_Per_Wavelength = 4;
transducer_Frequency_in_Hz = 5000000;
PRF = 100;
Imaging_TW_Index = 1;
Push_TW_Index = 2;
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

TW(2).type = 'parametric';
TW(2).Parameters = [18,17,2,1]; 
TW(2).extendBL = 1;

% Specify TPC structures.
TPC(1).name = '2D';
TPC(1).maxHighVoltage = 50;

TPC(5).name = 'Push';
TPC(5).maxHighVoltage = 50;

x = [1:128];
c = 10;
Apod_Gauss_Curve = exp(-((x-64.5).^2)./(2*c^2));
plot(Apod_Gauss_Curve)
title('Apdization curve')

% Specify TX structure array.
TX(1).waveform = 1; % use 1st TW structure.
TX(1).focus = 0;
TX(1).Apod =  Apod_Gauss_Curve;%ones(1,Trans.numelements);
TX(1).Delay = computeTXDelays(TX(1));

% Specify TX structure array.
TX(2).waveform = 2; % use 1st TW structure.
TX(2).focus = 0;
TX(2).Apod =  Apod_Gauss_Curve;%ones(1,Trans.numelements);
TX(2).Delay = computeTXDelays(TX(2));

% Specify TGC Waveform structure.
TGC(1).CntrlPts = [500,590,650,710,770,830,890,950];
TGC(1).rangeMax = 200;
TGC(1).Waveform = computeTGCWaveform(TGC);

% Specify SFormat structure arrays.
SFormat(1).transducer = 'L7-4';     % 128 element linear array with 1.0 lambda spacing
SFormat(1).scanFormat = 'RLIN';     % rectangular linear array scan
SFormat(1).radius = 0;              % ROC for curved lin. or dist. to virt. apex
SFormat(1).theta = 0;
SFormat(1).numRays = 1;             % no. of Rays (1 for Flat Focus)
SFormat(1).FirstRayLoc = [0,0,0];   % x,y,z
SFormat(1).rayDelta = 128*Trans.spacing;  % spacing in radians(sector) or dist. between rays (wvlnghts)
SFormat(1).startDepth = 0;      % Acquisition start depth in wavelengths
SFormat(1).endDepth = 2*(Point_Distance_in_mm/wavelength_in_mm);          % Acquisition end depth

PData(1).sFormat = 1;               % use first SFormat structure.
PData(1).pdeltaX = Trans.spacing;
PData(1).pdeltaZ = 1;
PData(1).Size(1,1) = ceil((SFormat(1).endDepth-SFormat(1).startDepth)/PData(1).pdeltaZ); % rows
PData(1).Size(1,2) = ceil((Trans.numelements*Trans.spacing)/PData.pdeltaX);
PData(1).Size(1,3) = 1;             % single image page
PData(1).Origin = [-Trans.spacing*(Trans.numelements-1)/2,0,SFormat(1).startDepth]; % x,y,z of uppr lft crnr.

Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = ceil(2*(points_Per_Wavelength*2*(Point_Distance_in_mm/wavelength_in_mm))); %range is set to double the target distance.
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = 10; % minimum size is 1 frame.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).rowsPerFrame = PData(1).Size(1,1); % this is for greatest depth
Resource.InterBuffer(1).colsPerFrame = PData.Size(2);
Resource.InterBuffer(1).numFrames = 1;  % one intermediate buffer needed.
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = PData(1).Size(1,1);
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = 10;

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
Recon = struct('senscutoff', 0.6, ...
               'pdatanum', 1, ...
               'rcvBufFrame', -1, ...     % use most recently transferred frame
               'IntBufDest', [1,1], ...
               'ImgBufDest', [1,-1], ...  % auto-increment ImageBuffer each recon
               'RINums', 1);
           
ReconInfo = struct('mode', 0, ...  % replace IQ data.
                   'txnum', Push_TW_Index, ...
                   'rcvnum', 1, ...
                   'regionnum', 0);
% - Set specific ReconInfo attributes.
ReconInfo(1).mode = 0;
ReconInfo(1).rcvnum = 1;

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
                        'callMediaFunc', 0),1,Resource.RcvBuffer(1).numFrames);
                    
% - Set event specific Receive attributes.
for i = 1:Resource.RcvBuffer(1).numFrames
    Receive(i).Apod = ones(1, 128);
    Receive(i).startDepth = 0;
    Receive(i).endDepth = 2*Point_Distance_in_mm/wavelength_in_mm;
    Receive(i).TGC = 1; % Use the first TGC waveform defined above
    Receive(i).mode = 0;
    Receive(i).bufnum = 1;
    Receive(i).framenum = i;
    Receive(i).acqNum = 1;
    Receive(i).samplesPerWave = points_Per_Wavelength;
    Receive(i).InputFilter = [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494];
    Receive(i).callMediaFunc =1;
end

% Specify SeqControl structure arrays.
SeqControl(1).command = 'jump'; % jump back to start.
SeqControl(1).argument = 1;
SeqControl(2).command = 'timeToNextAcq';  % time between frames
SeqControl(2).argument = 1000000*(1/PRF);  % 10 msec
SeqControl(3).command = 'returnToMatlab';
SeqControl(4).command = 'setTPCProfile';
SeqControl(4).condition = 'immediate';
SeqControl(4).argument = 5;
Event(1).info = 'Switch to Push Power Supply';
Event(1).tx = 0;   
Event(1).rcv = 0;   
Event(1).recon = 0;      % no reconstruction.
Event(1).process = 0;    % Try running the External Sweep Parameter Process
Event(1).seqControl = 4; % 

SeqControl(5).command = 'noop';
SeqControl(5).argument = 15*5000; % # of 200ns blocks.  Time Specified in ms.  
Event(2).info = 'Delay for Push Power Supply to Charge Up';
Event(2).tx = 0;
Event(2).rcv = 0;
Event(2).recon = 0;
Event(2).process = 0;
Event(2).seqControl = 5;
    
seq_Count = 6; % nsc is count of SeqControl objects
event_Count = 3;

% Specify sequence events.
for i = 1:Resource.RcvBuffer(1).numFrames
Event(event_Count).info = 'Acquire RF Data.';
Event(event_Count).tx = Push_TW_Index; % use 1st TX structure.
Event(event_Count).rcv = 1; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % no processing
Event(event_Count).seqControl = [2 seq_Count]; % transfer data to host

SeqControl(seq_Count).command = 'transferToHost';
seq_Count = seq_Count + 1;
event_Count = event_Count + 1;

Event(event_Count).info = 'Show RF';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = [1]; % no processing
Event(event_Count).seqControl = 0; % transfer data to host

event_Count = event_Count + 1;
Event(event_Count).info = 'Show Image';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 1; % no reconstruction.
Event(event_Count).process = [2]; % no processing
Event(event_Count).seqControl = 3; % transfer data to host

event_Count = event_Count + 1;
end

Event(event_Count).info = 'Jump back to first event';
Event(event_Count).tx = 0;        % no TX
Event(event_Count).rcv = 0;       % no Rcv
Event(event_Count).recon = 0;     % no Recon
Event(event_Count).process = 0; 
Event(event_Count).seqControl = 1; % jump command;

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
                         'displayWindow',1};
                     
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
VSX_Input_File = 'Test_Script1.mat';
save(VSX_Input_File);
disp(['Input file is: ', VSX_Input_File]);
VSX


