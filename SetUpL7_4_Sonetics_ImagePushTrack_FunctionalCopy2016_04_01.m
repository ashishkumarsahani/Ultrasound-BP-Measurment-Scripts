% Copyright 2001-2013 Verasonics, Inc.  All world-wide rights and remedies under all intellectual property laws and industrial property laws are reserved.  Verasonics Registered U.S. Patent and Trademark Office.
% 
% Generate .mat Sequence Object file for flash transmit Doppler imaging.
%   - For the 2D image, na flat focus transmits at steered angles are used.
%   - For the Doppler ensemble, ne flat focus pulses are transmitted at a
%     steering angle of dopAngle radians, receiving on all 128 elements
%   - This version also includes the use of TPC Profiles to provide a separate high voltage
%     for Doppler acquisition.
%
%   Last update: 03/29/2013

clear all;
close all;


% Sonetics Parameters DFL 2016-01-28
NumFrameStore = 90;
NumTrackingFrames = 2;
PixelX_WL = 0.05;  % Set reconstruction lateral grid size (in wavelengths)
PixelZ_WL = 0.05;  % Set reconstruction axial grid size (in wavelengths)

StartDepthWL = 70;
EndDepthWL = 110;
WidthPercent = 20;  % Width of the aperture to use for imaging (scale to <100% to reduce image width).
PushFocusWL = 80;

PulseRepPeriod = 5000; % Frame Period in milliseconds;
PushSupplyChargeTime = 15; % Initial Delay for HV supply to Charge up (in ms)

% Push and Tracking Timing Parameters 
push_iteration = 2;  % Creates multiple bursts of 64 x Nslider
time_us_between_push = 10; 
time_us_pushend2imagestart = 100; % 100us minimum to avoid artifact from push
trackPRF =9000; % PRF for tracking images; >10k generates reverb artifact!
ne = NumTrackingFrames;     % Set ne = number of acquisitions in Doppler ensemble.

% Initialization
FrameInfoList = zeros(NumFrameStore,3);
hvSetValueSonetics = 99;

% Set Tracking Frame parameters

dopAngle = 12 * pi/180;
dopPRF = 3.0e+03; % Doppler PRF in Hz.
pwrThres = 0.5;

% Specify system parameters.
Resource.Parameters.numTransmit = 128;  % number of transmit channels.
Resource.Parameters.numRcvChannels = 128;  % number of receive channels.
Resource.Parameters.speedOfSound = 1540;
Resource.Parameters.simulateMode = 0;
%  Resource.Parameters.simulateMode = 1 forces simulate mode, even if hardware is present.
%  Resource.Parameters.simulateMode = 2 stops sequence and processes RcvData continuously.
Resource.Parameters.connector = 1;


% Specify Trans structure array.
Trans.name = 'L7-4';
Trans = computeTrans(Trans);  % computeTrans is used for known transducers.
Trans.maxHighVoltage = 50;    % set a reasonable high voltage limit.

% Specify SFormat structure arrays.
% - 2D SFormat structure
SFormat(1).transducer = 'L7-4';     % 128 element linear array with 1.0 lambda spacing
SFormat(1).scanFormat = 'RLIN';     % rectangular linear array scan
SFormat(1).radius = 0;              % ROC for curved lin. or dist. to virt. apex
SFormat(1).theta = 0;
SFormat(1).numRays = 1;             % no. of Rays (1 for Flat Focus)
SFormat(1).FirstRayLoc = [0,0,0];   % x,y,z
SFormat(1).rayDelta = 128*Trans.spacing;  % spacing in radians(sector) or dist. between rays (wvlnghts)
SFormat(1).startDepth = StartDepthWL;      % Acquisition start depth in wavelengths
SFormat(1).endDepth = EndDepthWL;          % Acquisition end depth
        

% Specify PData structure arrays.
% - 2D PData structure
PData(1).sFormat = 1;               % use first SFormat structure.
PData(1).pdeltaX = PixelX_WL;
PData(1).pdeltaZ = PixelZ_WL;
PData(1).Size(1,1) = ceil((SFormat(1).endDepth-SFormat(1).startDepth)/PData(1).pdeltaZ); % rows
% PData(1).Size(1,2) = ceil((Trans.numelements*Trans.spacing)/PData(1).pdeltaX); % cols
PData(1).Size(1,2) = ceil(ceil(0.01*WidthPercent*Trans.numelements*Trans.spacing)/PData(1).pdeltaX);
PData(1).Size(1,3) = 1;             % single image page
PData(1).Origin = [-0.01*WidthPercent*Trans.spacing*63.5,0,SFormat(1).startDepth]; % x,y,z of uppr lft crnr.


% Specify Media object.
pt1;
Media.function = 'movePoints';

% Specify Resources.
% - RcvBuffer(1) is for both 2D and Tracking acquisitions.
Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = 2048*(1 + ne); % 1 ref acqusition + ne tracking acqusitions 
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters(1).numRcvChannels;
Resource.RcvBuffer(1).numFrames = NumFrameStore;           % # Frames allocated for RF acqusitions.
% InterBuffer(1) is for 2D Reference Image Reconstructions.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).numFrames = NumFrameStore;         
Resource.InterBuffer(1).rowsPerFrame = PData(1).Size(1); % DFL Changed from 2048
Resource.InterBuffer(1).colsPerFrame = PData(1).Size(2);
Resource.InterBuffer(1).pagesPerFrame = 1;
% InterBuffer(2) is for Tracking Reconstructions.
Resource.InterBuffer(2).datatype = 'complex';
Resource.InterBuffer(2).numFrames = NumFrameStore;          
Resource.InterBuffer(2).rowsPerFrame = PData(1).Size(1); % DFL Changed from 2048
Resource.InterBuffer(2).colsPerFrame = PData(1).Size(2); % DFL changed to (1) to keep tracking and image the same.
Resource.InterBuffer(2).pagesPerFrame = ne;     % ne pages per ensemble
% ImageBuffer(1) is for 2D Reference image.
Resource.ImageBuffer(1).datatype = 'double';    % image buffer for 2D
Resource.ImageBuffer(1).rowsPerFrame = 2048;    % this is for maximum depth
Resource.ImageBuffer(1).colsPerFrame = PData(1).Size(2);
Resource.ImageBuffer(1).numFrames = NumFrameStore;
% ImageBuffer(2) is for Tracking images.
Resource.ImageBuffer(2).datatype = 'double';    % image buffer for Doppler
Resource.ImageBuffer(2).rowsPerFrame = 2048;    % this is for maximum depth
Resource.ImageBuffer(2).colsPerFrame = PData(1).Size(2); %DFL changed to (1) to keep tracking and image the same.
Resource.ImageBuffer(2).numFrames = NumFrameStore;
Resource.ImageBuffer(2).pagesPerFrame = ne;     % ne pages per tracking ensemble
% DisplayWindow is for 2D combined with Doppler
Resource.DisplayWindow(1).Title = 'Image Display';
Resource.DisplayWindow(1).pdelta = 0.3;
Resource.DisplayWindow(1).Position = [250,150, ...    % lower left corner position
    ceil(PData(1).Size(2)*PData(1).pdeltaX/Resource.DisplayWindow(1).pdelta), ... % width
    ceil(PData(1).Size(1)*PData(1).pdeltaZ/Resource.DisplayWindow(1).pdelta)];    % height
Resource.DisplayWindow(1).ReferencePt = [PData(1).Origin(1),PData(1).Origin(3)]; % 2D imaging is in the X,Z plane
Resource.DisplayWindow(1).Colormap = grayscaleCFImap;
Resource.DisplayWindow(1).splitPalette = 0;


% ------Specify structures used in Events------
% Specify Transmit waveform structures.  
% - 2D transmit waveform
TW(1).type = 'parametric';
TW(1).Parameters = [18,17,2,1];   % A, B, C, D
% - Doppler transmit waveform
TW(2).type = 'parametric'; 
TW(2).Parameters = [18,17,6,1];   % A, B, C, D
% - Push transmit waveform
push_pulse_halfcyc_number = 31;
% parametric_A_push = 18;
% TW_push_freq_MHz = 180/2/parametric_A_push;
TW_push_freq_MHz = 5;
 [ parametric_A_push, ~,TW_push_freq_MHz ] = TW_parameter_generator( TW_push_freq_MHz );
 
TW(3).type = 'parametric';
TW(3).Parameters = [parametric_A_push,17,push_pulse_halfcyc_number,1];   % A, B, C, D
TW(3).extendBL = 1;

push_pulse_duration_us = (push_pulse_halfcyc_number/2)/TW_push_freq_MHz *64 ; %  TW(3).extendBL = 1; =>64 times

push_total_duration_us = push_pulse_duration_us*push_iteration + ...
                        time_us_between_push * (push_iteration-1);


% Specify TX structure array.  
TX = repmat(struct('waveform', 1, ...
                   'Origin', [0.0,0.0,0.0], ...
                   'focus', 0.0, ...
                   'Steer', [0.0,0.0], ...
                   'Apod', ones(1,Resource.Parameters(1).numTransmit), ...
                   'Delay', zeros(1,Resource.Parameters(1).numTransmit)), 1, 2); % na TXs for 2D + 1 for Doppler
% - Set event specific TX attributes.
% -- Reference Image is planar transmit, with 0 delays
% -- Create Push Transmit Structure with Focus

% TX(1).focus = PushFocusWL;
TX(2).waveform = 3;
TX(2).Steer = [0.0,0.0];
TX(2).focus = PushFocusWL; % Focus the push pulse at depth specified in wavelength units
TX(2).Delay = computeTXDelays(TX(2));
TX(2).Apod = [zeros(1,32),ones(1,64),zeros(1,32)]; % Added to make default ON
% TX(2).Apod = zeros(1,Resource.Parameters(1).numTransmit); % Toggles on and off with ext transmit radio buttons.

% Specify TPC structures.
TPC(1).name = '2D';
TPC(1).maxHighVoltage = 50;
% TPC(2).name = 'Doppler';
% TPC(2).maxHighVoltage = 35;
TPC(3).name = 'Doppler';
TPC(3).maxHighVoltage = 50;
TPC(5).name = 'Push';
TPC(5).maxHighVoltage = 50;


% BUILD RECEIVE STRUCTURE ARRAY
%   We need to acquire all the 2D and Post-Push data within a single RcvBuffer frame.  This allows
%   the transfer-to-host DMA after each frame to transfer a large amount of data, improving throughput.
% - We need na Receives for a 2D frame and ne Receives for a post-push frame. 
 
maxAcqLngth2D = sqrt(SFormat(1).endDepth^2 + (Trans.numelements*Trans.spacing)^2) - SFormat(1).startDepth;
% maxAcqLngthDop =  sqrt(SFormat(2).endDepth^2 + (96*Trans.spacing)^2) - SFormat(2).startDepth;
wl4sPer128 = 128/(4*2);  % wavelengths in a 128 sample block for 4 smpls per wave round trip.
wl2sPer128 = 128/(4*2);  % wavelengths in a 128 sample block for 4 smpls per wave round trip. (DFL changed to 4 s/wl on 2016-02-02)

apodwin = hann(128)';
%     Receive = repmat(struct('Apod', ones(1,Resource.Parameters(1).numRcvChannels), ...
Receive = repmat(struct('Apod', apodwin, ...
                        'startDepth', SFormat(1).startDepth, ...
                        'endDepth', SFormat(1).startDepth + wl4sPer128*ceil(maxAcqLngth2D/wl4sPer128), ...
                        'TGC', 1, ...
                        'bufnum', 1, ...
                        'framenum', 1, ...
                        'acqNum', 1, ...
                        'samplesPerWave', 4, ... % samplesPerWave for 2D
                        'mode', 0, ...
                        'InputFilter', [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494], ...
                        'callMediaFunc', 0), 1, (1+ne)*Resource.RcvBuffer(1).numFrames);
%   'InputFilter', [-0.0141,0.0420,-0.0825,0.1267,-0.1612,0.1783], ...  % bandpass filter for Doppler (~ 20% BW)
% - Set event specific Receive attributes.
for i = 1:Resource.RcvBuffer(1).numFrames
    k = (1 + ne)*(i-1); % k keeps track of Receive index increment per frame.
    % - Set attributes for each frame.
    Receive(k+1).callMediaFunc = 1;
    for j = 1:(1+ne)  % acquisitions for reference and tracking frames
        Receive(j+k).framenum = i;
        Receive(j+k).acqNum = j;
    end
    
end

% Specify TGC Waveform structures.
% - 2D TGC
% TGC(1).CntrlPts = [400,500,625,700,750,800,850,950];
TGC(1).CntrlPts = [40,50,62.5,70.0,75.0,80.0,85.0,95.0];
TGC(1).rangeMax = SFormat(1).endDepth;
TGC(1).Waveform = computeTGCWaveform(TGC(1));


% Specify Recon structure arrays.
% - We need two Recon structures, one for reference, one for tracking. These will be referenced in the same
%   event, so that they will use the same (most recent) acquisition frame.
    
Recon = repmat(struct('senscutoff', 0.7, ...
               'pdatanum', 1, ...
               'rcvBufFrame', -1, ...
               'IntBufDest', [1,1], ...
               'ImgBufDest', [1,-1], ...
               'RINums', zeros(1,1)), 1, NumFrameStore*2);

           for i = 1:NumFrameStore
               
               % - Set Recon values for 2D frame.
               Recon(1+2*(i-1)).RINums(1,1) = (1+ne)*(i-1)+1;  % Just 1 recon info number needed for Ref image
               Recon(1+2*(i-1)).IntBufDest = [1,i];
               
               % - Set Recon values for Tracking ensemble.
               Recon(2+2*(i-1)).pdatanum = 1;  %
               Recon(2+2*(i-1)).IntBufDest = [2,i];
               Recon(2+2*(i-1)).ImgBufDest = [2,-1];
               Recon(2+2*(i-1)).RINums(1:ne,1) = ((ne+1)*(i-1)+(2:ne+1))';   % ne ReconInfos needed for tracking ensemble.
           end


% Define ReconInfo structures.
% - For 2D, we need na ReconInfo structures for na steering angles.
% - For tracking, we need ne ReconInfo structures.
ReconInfo = repmat(struct('mode', 4, ...    % accumulate IQ data.
                   'txnum', 1, ...
                   'rcvnum', 1, ...
                   'pagenum',1, ...
                   'regionnum', 0), 1, NumFrameStore*(1 + ne));
% - Set specific ReconInfo attributes.
%   - ReconInfos for 2D frame.
% ReconInfo(1).mode = 3; % replace IQ data at the first line

for i = 1:NumFrameStore
    
    ReconInfo(1+(1+ne)*(i-1)).mode = 0;
    ReconInfo(1+(1+ne)*(i-1)).txnum = 1;
    ReconInfo(1+(1+ne)*(i-1)).rcvnum = (1+ne)*(i-1)+1;
    ReconInfo(1+(1+ne)*(i-1)).pagenum = 1;
    
    for j = 1:ne
        ReconInfo(j+1+(1+ne)*(i-1)).mode = 0; % Replace IQ data each time (on new page)
        ReconInfo(j+1+(1+ne)*(i-1)).txnum = 1;
        ReconInfo(j+1+(1+ne)*(i-1)).rcvnum = (1+ne)*(i-1) + j+1;
        ReconInfo(j+1+(1+ne)*(i-1)).pagenum = j;
    end
end

%%
% Specify Process structure arrays.
cpt = 28;  % define here so we can use in UIControl below
persf = 80;
persp = 90;
DopState = 'freq';
Process(1).classname = 'Image';
Process(1).method = 'imageDisplay';
Process(1).Parameters = {'imgbufnum',1,...          % number of ImageBuffer to process.
                         'framenum',-1,...          % frame number in source buffer (-1 => lastFrame)
                         'pdatanum',1,... 
                         'norm',1,...               % normalization method(1 means fixed)
                         'pgain',1.0,...            % pgain is image processing gain
                         'persistMethod','simple',...
                         'persistLevel',20,...
                         'interp',1,...             % method of interpolation (1=4pt interp)
                         'compression',0.5,...      % X^0.5 normalized to output word size
                         'reject',2,...
                         'mappingMode','full',...%'lowerHalf',...
                         'displayWindow',1,...
                         'display',1};              % don't display image after processing

Process(2).classname = 'Doppler';                   % process structure for 1st Doppler ensemble
Process(2).method = 'computeCFIFreqEst';
Process(2).Parameters = {'srcbufnum',2,...          % number of buffer to process.
                         'srcframenum',1,...        % start frame number in source buffer
                         'srcpagenum',3,...
                         'dstbufnum',2,... 
                         'dstframenum',-1,...       % frame number in destination buffer
                         'pdatanum',2,...           % number of PData structure
                         'prf',dopPRF,...           % Doppler PRF in Hz
                         'numPRIs',ne-2,...
                         'wallFilter','regression',...  % 1 -> quadratic regression
                         'pwrThreshold',pwrThres,...
                         'postFilter',1};

Process(3).classname = 'Image';                     % image display for color data.
Process(3).method = 'imageDisplay';
Process(3).Parameters = {'imgbufnum',2,...          % number of buffer to process.
                         'framenum',-1,...          % frame number in source buffer (-1 => lastFrame)
                         'srcData','signedColor',... % type of data to display.
                         'pdatanum',2,... 
                         'norm',2,...               % normalization method(2 means none)
                         'pgain',1.0,...            % pgain is image processing gain
                         'persistMethod','dynamic',...
                         'persistLevel',persf,...
                         'interp',1,...             % method of interpolation (1=4pt interp)
                         'compression',0.5,...      % X^0.5 normalized to output word size
                         'mappingMode','upperHalf',...
                         'threshold',cpt,...
                         'displayWindow',1,...
                         'display',1};              % display image after processing

Process(4).classname = 'External';
Process(4).method = 'sweepParameter';
Process(4).Parameters = {'srcbuffer','none',... % buffer to process.
                        'dstbuffer','none'}; % no output buffer
Process(5).classname = 'External';
Process(5).method = 'Sonetics_ExtScript';
Process(5).Parameters = {'srcbuffer','none',... % buffer to process.
                        'dstbuffer','none'}; % no output buffer


% SET STATIC SEQUENCE CONTROL FOR ARGUMENTS THAT CHANGE WITH GUI ENTRY

% Set Sequence Control for Burst Length
SeqControl(1).command = 'timeToNextEB';%
SeqControl(1).argument =  max(push_pulse_duration_us + time_us_between_push + 8,...
                               time_us_between_push); % time in usec :between EB                            
% Set Sequence Control for Last Burst                      
SeqControl(2).command = 'timeToNextAcq';
SeqControl(2).argument = push_pulse_duration_us+time_us_pushend2imagestart;  % time in us: push end to image start duration

% Set Sequence Control for Delay to Achieve PRF
SeqControl(3).command = 'noop';
SeqControl(3).argument = round(((PulseRepPeriod*1000 - 300 - push_total_duration_us - ...
    (NumTrackingFrames*1E6/trackPRF))/100)/0.2); 

% Set Sequence Control for Transfering Data to Host
SeqControl(4).command = 'timeToNextAcq';%
SeqControl(4).argument =  10000; % time in usec 

lastTTHnsc = 0;

% DEFINE EVENT SEQUENCE, WITH SEQUENCE CONTROL IN-LINE (Except for a few)

nsc = 5;  % Define starting point for variable to keep track of sequence control number

% Specify Event structure arrays.
n = 1; % Variable to keep track of event number.

    % Start by Switching to the Push Pulse Power Supply and Wait to Charge
    
    SeqControl(nsc).command = 'setTPCProfile';
    SeqControl(nsc).condition = 'immediate';
    SeqControl(nsc).argument = 5;
    Event(n).info = 'Switch to Push Power Supply';
    Event(n).tx = 0;   
    Event(n).rcv = 0;   
    Event(n).recon = 0;      % no reconstruction.
    Event(n).process = 0;    % Try running the External Sweep Parameter Process
    Event(n).seqControl = nsc; % 
    n = n+1;
    nsc = nsc + 1;
    
    SeqControl(nsc).command = 'noop';
    SeqControl(nsc).argument = PushSupplyChargeTime*5000; % # of 200ns blocks.  Time Specified in ms.  
    Event(n).info = 'Delay for Push Power Supply to Charge Up';
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = nsc;
    n = n+1;
    nsc = nsc + 1;

    for i = 1:NumFrameStore
        
        % Sync hardware and software
        SeqControl(nsc).command = 'sync';
        SeqControl(nsc).argument = 30E6; % Timeout
        nsc = nsc+1;
        
        % Issue a trigger
        SeqControl(nsc).command = 'triggerOut';
        Event(n).info = 'Trigger Out';
        Event(n).tx = 0;
        Event(n).rcv = 0;
        Event(n).recon = 0;
        Event(n).seqControl = [nsc,nsc-1];
        Event(n).process = 4;
        n = n + 1;
        nsc = nsc + 1;
        
        % Acquire Reference Image before Push Pulse
        SeqControl(nsc).command = 'timeToNextAcq';
        SeqControl(nsc).argument = 3000; % Wait 3000 us after acquiring
        Event(n).info = 'Acquire Reference Image (Planar TX)';
        Event(n).tx = 1;
        Event(n).rcv = (1+ne)*(i-1) + 1;  % Increment Receive line by (ref+trackingnum) for each frame
        Event(n).recon = 0;
        Event(n).process = 0;    % no processing
        Event(n).seqControl = nsc;
        n = n + 1;
        nsc = nsc + 1;
        
        
        % Apply the push pulse (Use Fixed Sequence Control 1 as Defined Above)
        for qwe = 1:push_iteration
            Event(n).info = 'Push pulse';
            Event(n).tx = 2;   % use push TX structure.
            Event(n).rcv = 0;   % Push Only (no RX)
            Event(n).recon = 0;      % no reconstruction.
            Event(n).process = 0;    % no processing
            Event(n).seqControl = 1; % timeToNextEB
            n = n+1;
        end
        % Apply last push pulse (Use Fixed Sequence Control 2 as Defined Above)
        Event(n-1).info = 'Last push pulse'; % Overwrite last push pulse title
        Event(n-1).seqControl = 2;  % Change delay after last push-pulse to set timing of first tracking frame
        
        % Acquire Tracking ensemble.
        SeqControl(nsc).command = 'timeToNextAcq';
        SeqControl(nsc).argument = round(1/(trackPRF*1e-06)); % Set delay between tracking images
        for j = 2:(ne+1) % Add events for each tracking acquisition
            Event(n).info = 'Acquire Tracking Frame, Planar TX';
            Event(n).tx = 1;      % use same transmit structure as reference pulse
            Event(n).rcv = (ne+1)*(i-1)+j;
            Event(n).recon = 0;      % no reconstruction.
            Event(n).process = 0;    % no processing
            Event(n).seqControl = nsc; % Time to next acq for tracking
            n = n+1;
        end
        nsc = nsc + 1;
        
        %     Event(n-1).seqControl = [4,nsc]; % replace last tracking acquisition Event's seqControl
        %       SeqControl(nsc).command = 'transferToHost'; % transfer frame to host buffer
        %       nsc = nsc+1;
        Event(n-1).seqControl = nsc;
        SeqControl(nsc).command = 'transferToHost';
        SeqControl(nsc).condition = 'waitForProcessing';
        SeqControl(nsc).argument = lastTTHnsc;
        lastTTHnsc = nsc;
        nsc = nsc + 1;
        
        % Do Recon for Reference 2D Image
        
        Event(n).info = 'Recon Reference Image -> Output to IQData(1) Pages';
        Event(n).tx = 0;         % no transmit
        Event(n).rcv = 0;        % no rcv
        Event(n).recon = 1+(i-1)*2;  % reconstruction for both 2D
        Event(n).process = 1;    % process 2D
        Event(n).seqControl = 0;
        n = n + 1;
        
        % Do Recon for tracking images
        Event(n).info = 'Recon Tracking Images -> Output to IQData(2) Pages';
        Event(n).tx = 0;         % no transmit
        Event(n).rcv = 0;        % no rcv
        Event(n).recon = 2+(i-1)*2;  % reconstruction for both 2D
        Event(n).process = 5;    % Run Sonetics External Script
        Event(n).seqControl = 0;
        n = n + 1;
        
        SeqControl(nsc-1).argument = lastTTHnsc; %#ok<*SAGROW>
        
        % Wait for Delay to Achieve Frame Rate
        j = 1;
        for j = 1:100  % Divide total delay time into 100 chunks
            Event(n).info = 'Delay to achieve target PRF';
            Event(n).tx = 0;
            Event(n).rcv = 0;
            Event(n).recon = 0;
            Event(n).process = 0;
            Event(n).seqControl = 3;
            n = n+1;
        end
        n = n-1;
        
        if floor(i/1) == i/1     % Exit to Matlab every 1 frame
            Event(n).seqControl = nsc;
            SeqControl(nsc).command = 'returnToMatlab';
            nsc = nsc+1;
        end
        n = n+1;
    end

SeqControl(nsc).command = 'jump';
SeqControl(nsc).argument = 3;
Event(n).info = 'Jump back';
Event(n).tx = 0;        % no TX
Event(n).rcv = 0;       % no Rcv
Event(n).recon = 0;     % no Recon
Event(n).process = 0; 
Event(n).seqControl = nsc;
nsc = nsc + 1;



%%
% User specified UI Control Elements
% - Sensitivity Cutoff
UI(1).Control =  {'UserB7','Style','VsSlider','Label','Sens. Cutoff',...
                  'SliderMinMaxVal',[0,1.0,Recon(1).senscutoff],...
                  'SliderStep',[0.025,0.1],'ValueFormat','%1.3f'};
UI(1).Callback = text2cell('%-UI#1Callback');


% - Push button
UI(5).Control = {'UserB6','Style','VsButtonGroup','Title','Push','NumButtons',2,'Labels',{'No','Yes'}};
UI(5).Callback = text2cell('%-UI#5Callback');


% - push pulse length
UI(6).Control =  {'UserB5','Style','VsSlider','Label','Push pulse cyc #',...
                  'SliderMinMaxVal',[1,31,round(push_pulse_halfcyc_number)],...
                  'SliderStep',[0.025,0.1],'ValueFormat','%2.0f'}; % SliderStep is the fraction of full slider
UI(6).Callback = text2cell('%-UI#6Callback');

% - push pulse freq
UI(7).Control =  {'UserC3','Style','VsSlider','Label','Push freq',...
                  'SliderMinMaxVal',[3,8,TW_push_freq_MHz],...
                  'SliderStep',[0.025,0.1],'ValueFormat','%1.2f'}; % SliderStep is the fraction of full slider
UI(7).Callback = text2cell('%-UI#7Callback');
%%
% Specify factor for converting sequenceRate to frameRate.
frameRateFactor = 1;

% Save all the structures to a .mat file.
filename = 'L7-4FlashPush_Trigger';
save(filename);
VSX
return


% **** Callback routines to be encoded by text2cell function. ****
%-UI#1Callback - Sensitivity cutoff change
ReconL = evalin('base', 'Recon');
for i = 1:size(ReconL,2)
    ReconL(i).senscutoff = UIValue;
end
assignin('base','Recon',ReconL);
Control = evalin('base','Control');
PulseRepPeriod = evalin('base','PulseRepPeriod');
Control.Command = 'update&Run';
Control.Parameters = {'Recon'};
assignin('base','Control', Control);
return
%-UI#1Callback

%-UI#2Callback - Doppler mode change
Control = repmat(struct('Command','set&Run','Parameters',[]),1,4);
switch UIState
   case 1  % Velocity mode
      assignin('base','persp',get(findobj('Tag','persistSlider'),'Value'));
      persf = evalin('base','persf');
      Control(1).Parameters = {'Process',2,'method','computeCFIFreqEst'};
      Control(2).Parameters = {'Process',3,'srcData','signedColor','persistMethod','dynamic','persistLevel',persf};
      Control(3).Parameters = {'DisplayWindow',1,'colormap',grayscaleCFImap};
      Control(4).Parameters = {'ImageBuffer',1,'lastFrame',0};
      h = findobj('tag','persistValue');
      set(h,'String',num2str(persf,'%3.0f'));
      h = findobj('tag','persistSlider');
      set(h,'Value',persf);
      assignin('base','DopState','freq');
      % Set modified Process attributes in base Matlab environment.
      Process = evalin('base','Process');
      Process(2).method = 'computeCFIFreqEst';
      Process(3).Parameters{6} = 'signedColor';
      Process(3).Parameters{14} = 'dynamic';
      Process(3).Parameters{16} = persf;
      assignin('base','Process',Process);
   case 2  % Power mode
      assignin('base','persf',get(findobj('Tag','persistSlider'),'Value'));
      persp = evalin('base','persp');
      Control(1).Parameters = {'Process',2,'method','computeCFIPowerEst'};
      Control(2).Parameters = {'Process',3,'srcData','unsignedColor','persistMethod','simple','persistLevel',persp};
      Control(3).Parameters = {'DisplayWindow',1,'colormap',grayscaleCPAmap};
      Control(4).Parameters = {'ImageBuffer',1,'lastFrame',0};
      h = findobj('tag','persistValue');
      set(h,'String',num2str(persp,'%3.0f'));
      h = findobj('tag','persistSlider');
      set(h,'Value',persp);
      assignin('base','DopState','power');
      Process = evalin('base','Process');
      Process(2).method = 'computeCFIPowerEst';
      Process(3).Parameters{6} = 'unsignedColor';
      Process(3).Parameters{14} = 'simple';
      Process(3).Parameters{16} = persp;
      assignin('base','Process',Process);
end
assignin('base','Control', Control);                  
%-UI#2Callback

%-UI#3Callback - Doppler Power change
% Set Control.Command to set Doppler threshold.
Control = evalin('base','Control');
Control.Command = 'set&Run';
Control.Parameters = {'Process',2,'pwrThreshold',UIValue};
assignin('base','Control', Control);
%-UI#3Callback

%-UI#4Callback - Color Priority change
% Set the value in the Process structure for use in cineloop playback.
Process = evalin('base','Process');
Process(3).Parameters{24} = UIValue;
assignin('base','Process',Process);
% Set Control.Command to set Image.threshold.
Control = evalin('base','Control');
Control.Command = 'set&Run';
Control.Parameters = {'Process',3,'threshold',UIValue};
assignin('base','Control', Control);
%-UI#4Callback

%-UI#5Callback - Push mode change
% TX(na+2).Apod = zeros(1,Resource.Parameters(1).numTransmit);
Control = repmat(struct('Command','update&Run','Parameters',[]),1,1);
switch UIState
   case 1  % No push mode
%       na = evalin('base','na');       
%       Control(1).Parameters = {'TX',na+2,'Apod', zeros(1,128)};   %Resource.Parameters.numTransmit
      Control(1).Parameters = {'TX'};   
      % Set modified Process attributes in base Matlab environment.
      TX = evalin('base','TX');      
      TX(2).Apod = zeros(1,128);
      assignin('base','TX',TX);
      
   case 2  % Push mode
%       na = evalin('base','na');       
%       Control(1).Parameters = {'TX',na+2,'Apod', zeros(1,128)};   
      Control(1).Parameters = {'TX'};   

      TX = evalin('base','TX');      
      TX(2).Apod = [zeros(1,32),ones(1,64),zeros(1,32)];%ones(1,128);
      assignin('base','TX',TX);

end
assignin('base','Control', Control);                  
%-UI#5Callback


%-UI#6Callback - Push pulse length change
% % - Push transmit waveform
% TW(3).type = 'parametric';
% TW(3).Parameters = [18,17,push_pulse_halfcyc_number,1];   % A, B, C, D
% Control = repmat(struct('Command','set&Run','Parameters',[]),1,4);
global vector_input sweepVariable
if numel(UIValue) == 1 % for one value
    Control = repmat(struct('Command','update&Run','Parameters',[]),1,1);
    Control(1).Parameters = {'TW','SeqControl'};  
    push_pulse_halfcyc_number = round(UIValue);
    assignin('base','push_pulse_halfcyc_number',push_pulse_halfcyc_number);

    TW = evalin('base','TW');      
    TW(3).Parameters(:,3) = push_pulse_halfcyc_number;   % A, B, C, D
    assignin('base','TW',TW);

    TW_push_freq_MHz = evalin('base','TW_push_freq_MHz');  
    push_iteration = evalin('base','push_iteration');  
    time_us_between_push = evalin('base','time_us_between_push');  
    time_us_pushend2imagestart = evalin('base','time_us_pushend2imagestart'); 
    PulseRepPeriod = evalin('base','PulseRepPeriod');
    NumTrackingFrames = evalin('base','NumTrackingFrames');
    trackPRF = evalin('base','trackPRF');

    push_pulse_duration_us = (push_pulse_halfcyc_number/2)/TW_push_freq_MHz *64 ; %  TW(3).extendBL = 1; =>64 times
    push_total_duration_us = push_pulse_duration_us*push_iteration + ...
                            time_us_between_push * (push_iteration-1);
    assignin('base','push_pulse_duration_us',push_pulse_duration_us);
    assignin('base','push_total_duration_us',push_total_duration_us);

    SeqControl = evalin('base','SeqControl');  


%     % -- Time between Push pulses
    SeqControl(1).argument =  max(push_pulse_duration_us+time_us_between_push,...
                                   time_us_between_push); % time in usec :between EB
%     % -- Time between Push pulse and first 2D flash angle acquisition
    SeqControl(2).argument = push_pulse_duration_us+time_us_pushend2imagestart;  % time in us: push end to image start duration
    
    SeqControl(3).argument = round(((PulseRepPeriod*1000 - 300 - push_total_duration_us - ...
    (NumTrackingFrames*1E6/trackPRF))/100)/0.2)
% 
    assignin('base','SeqControl',SeqControl);
    assignin('base','Control', Control);
else % value sweeping
    vector_input  = round(UIValue);
    sweepVariable = 'pulse_length';
end
return
%-UI#6Callback

%-UI#7Callback - Push pulse freq change
% % - Push transmit waveform
% TW(3).type = 'parametric';
% TW(3).Parameters = [18,17,push_pulse_halfcyc_number,1];   % A, B, C, D
% Control = repmat(struct('Command','set&Run','Parameters',[]),1,4);
global vector_input sweepVariable
if numel(UIValue) == 1 % for one value
    Control = repmat(struct('Command','update&Run','Parameters',[]),1,1);
    Control(1).Parameters = {'TW','SeqControl'};  
    TW_push_freq_MHz = round(UIValue);
    [ parametric_A_push, ~,TW_push_freq_MHz ] = TW_parameter_generator( TW_push_freq_MHz );
    assignin('base','TW_push_freq_MHz',TW_push_freq_MHz);

    TW = evalin('base','TW');      
    TW(3).Parameters(:,1) = parametric_A_push;   % A, B, C, D
    TW(3).Parameters(:,2) = parametric_A_push-1;   % A, B, C, D
    assignin('base','TW',TW);

    push_pulse_halfcyc_number = evalin('base','push_pulse_halfcyc_number');  
    push_iteration = evalin('base','push_iteration');  
    time_us_between_push = evalin('base','time_us_between_push');  
    time_us_pushend2imagestart = evalin('base','time_us_pushend2imagestart');  

    push_pulse_duration_us = (push_pulse_halfcyc_number/2)/TW_push_freq_MHz *64 ; %  TW(3).extendBL = 1; =>64 times
    push_total_duration_us = push_pulse_duration_us*push_iteration + ...
                            time_us_between_push * (push_iteration-1);
%     assignin('base','push_pulse_duration_us',push_pulse_duration_us);
%     assignin('base','push_total_duration_us',push_total_duration_us);

%     SeqControl = evalin('base','SeqControl');  
%     % -- Time between Push pulse and first 2D flash angle acquisition
%     SeqControl(2).argument = push_pulse_duration_us+time_us_pushend2imagestart;  % time in us: push end to image start duration
%     % SeqControl(12).condition = 'ignore';
%     % -- Time between Push pulses
%     SeqControl(1).argument =  max(push_pulse_duration_us+time_us_between_push,...
%                                    time_us_between_push); % time in usec :between EB
% 
%     assignin('base','SeqControl',SeqControl);
%     assignin('base','Control', Control);
else % value sweeping
    vector_input  = round(UIValue);
    sweepVariable = 'pulse_freq';
end
return
%-UI#7Callback