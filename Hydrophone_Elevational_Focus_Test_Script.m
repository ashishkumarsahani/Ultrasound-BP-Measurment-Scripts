%%%Hydrophone Measurement Code For Elevational FOcus
Mcr_GuiHide = 1; %Control panel hide
Mcr_DisplayHide = 1; %Display window hide

clear Media;
reset_Phantom = 1;
pt1;
Media.function = 'move_Points';

clear TW;
% Specify the imaging transmit pulse.
TW(1).type = 'parametric';
TW(1).Parameters = [18,17,2,1];

% Specify all the the push pulse structures

TW(2).type = 'parametric';
if(Resource.Parameters.simulateMode ==1)
    TW(2).Parameters = [18,17,3,1];
else
    TW(2).Parameters = [18,17,number_Of_Cycles_Per_SubPulse,1];
end
TW(2).extendBL = 1;

clear TX;

image_TX_Num = 1;
TX(image_TX_Num).waveform = 1; % use 2nd TW structure.
TX(image_TX_Num).Origin = [focal_X, 0, 0];
central_Element = find(Trans.ElementPos >= focal_X, 1, 'first');
TX(image_TX_Num).focus = focal_Length;
TX(image_TX_Num).Apod =  zeros(1,Trans.numelements);
TX(image_TX_Num).Apod(central_Element-32:central_Element+32) = 1;
TX(image_TX_Num).Steer = [0 0];
TX(image_TX_Num).Delay = computeTXDelays(TX(image_TX_Num));

% Specify TGC Waveform structure.
clear TGC
TGC(1).CntrlPts = [500,590,650,710,770,830,890,950];
TGC(1).rangeMax = 200;
TGC(1).Waveform = computeTGCWaveform(TGC);
TGC(1).Waveform = (TGC(1).Waveform*0 +0.001); %Remove TGC

% Specify TPC structures.
clear TPC;
TPC(1).name = '2D';
TPC(1).maxHighVoltage = 100;
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
Resource.RcvBuffer(1).numFrames = 1; % minimum size is 1 frame.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).rowsPerFrame = PData(1).Size(1,1); % this is for greatest depth
Resource.InterBuffer(1).colsPerFrame = PData.Size(2);
Resource.InterBuffer(1).numFrames = 1;  %one intermediate buffer needed.
Resource.InterBuffer(1).pagesPerFrame = 1;
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = PData(1).Size(1,1);
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = 1;
Resource.ImageBuffer(1).pagesPerFrame = 1; 
Resource.VDAS.dmaTimeout = 100;

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
               'RINums', 1), 1, 1);

clear ReconInfo;
ReconInfo = repmat(struct('mode', 4, ...  % default accumulate IQ data.
                   'txnum', 1, ...
                   'rcvnum', 1, ...
                   'pagenum',1,...
                   'regionnum', 0), 1, 1);

% - Set event specific Recon attributes.

ReconInfo(1).mode = 0;
ReconInfo(1).rcvnum = 1;
ReconInfo(1).pagenum = 1;
ReconInfo(1).txnum = 1;
Recon(1).ImgBufDest = [1,1];
Recon(1).IntBufDest = [1,1];
Recon(1).RINums = 1;
Recon(1).newFrameTimeout= 1;

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
                        'callMediaFunc', 0),1,1);
                    
% - Set event specific Receive attributes.
Receive(1).Apod = ones(1, 128);
Receive(1).startDepth = 0;
Receive(1).endDepth = end_RF_Depth/wavelength_in_mm;
Receive(1).TGC = 1; % Use the first TGC waveform defined above
Receive(1).mode = 0;
Receive(1).bufnum = 1;
Receive(1).framenum = 1;
Receive(1).acqNum = 1;
Receive(1).samplesPerWave = RF_Points_Per_Wavelength;
Receive(1).InputFilter = [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494];
Receive(1).callMediaFunc = 1;

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
SeqControl(2).argument = 524287; % # Wait 102 milliseconds 

SeqControl(3).command = 'jump'; % jump back to start.
SeqControl(3).argument = 5;

SeqControl(4).command = 'triggerOut';  % This sequence controls the time between the flash angles if any
% SeqControl(4).argument = 1;

SeqControl(5).command = 'returnToMatlab';
SeqControl(6).command = 'sync';
SeqControl(6).argument = 30E6; % Timeout

seq_Count = 7; 
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
Event(event_Count).process = 1; %Set voltage and move the voltage pointer to the next voltage
Event(event_Count).seqControl = 2;
event_Count = event_Count+1;

%Sync hardware and software
Event(event_Count).info = 'Sync HW and SW';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; %Set voltage and move the voltage pointer to the next lower voltage
Event(event_Count).seqControl = 6;
event_Count = event_Count+1;

Event(event_Count).info = 'Create Trigger Out';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % read voltage here
Event(event_Count).seqControl = 4; %no delay between flash angles required here
event_Count = event_Count+1;

Event(event_Count).info = 'Acquire the ref. image';
Event(event_Count).tx = 1; % use 1st TX structure.
Event(event_Count).rcv = 1; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % read voltage here
Event(event_Count).seqControl = seq_Count; 
event_Count = event_Count+1;

SeqControl(seq_Count).command = 'transferToHost';
seq_Count = seq_Count+1;

Event(event_Count).info = 'Reconstruction';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 1; % reconstruction.
Event(event_Count).process = 3; % Show images
Event(event_Count).seqControl = 2; %Delay for 102 ms here
event_Count = event_Count + 1;

Event(event_Count).info = 'Return to matlab';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 0; % 
Event(event_Count).seqControl = 5; % no processing
event_Count = event_Count + 1;

Event(event_Count).info = 'Loop back';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 0; % 
Event(event_Count).seqControl = 3; % no processing
event_Count = event_Count + 1;

% Specify Process structure array.
pers = 40;

Process(1).classname = 'External';
Process(1).method = 'setHighVoltage';
Process(1).Parameters = {};

Process(2).classname = 'External';
Process(2).method = 'readHighVoltage';
Process(2).Parameters = {};

Process(3).classname = 'Image';
Process(3).method = 'imageDisplay';
Process(3).Parameters = {'imgbufnum',1,...   % number of buffer to process.
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

% Save all the structures to a .mat file.
filename = 'elevational_Focus_Script.mat';
save(filename);
VSX

