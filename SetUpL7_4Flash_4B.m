% Copyright 2001-2013 Verasonics, Inc.  All world-wide rights and remedies under all intellectual property laws and industrial property laws are reserved.  Verasonics Registered U.S. Patent and Trademark Office.
%
% File name SetUpL7_4Flash_4B.m:
% Generate .mat Sequence Object file for L7-4 Linear array flash transmit using 4 VDAS modules.
% 128 transmit channels and 128 receive channels are used, with a single flat focus transmit. 
%
% Last update 03-29-2013

% Specify system parameters.
% Resource.Parameters.numTransmit = 128;      % number of transmit channels.
% Resource.Parameters.numRcvChannels = 128;    % number of receive channels.

%  Resource.Parameters.simulateMode = 1 forces simulate mode, even if hardware is present.
%  Resource.Parameters.simulateMode = 2 stops sequence and processes RcvData continuously.

% Specify Trans structure array.
% clear Trans;
% Trans.name = 'L7-4';
% Trans = computeTrans(Trans);  % L7-4 transducer is 'known' transducer so we can use computeTrans.
% Trans.maxHighVoltage = 50;  % set maximum high voltage limit for pulser supply.

% Specify SFormat structure array.
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

% Specify PData structure array.
% clear PData;
% PData.sFormat = 1;      % use first SFormat structure.
% PData.pdeltaX = Trans.spacing;
% PData.pdeltaZ = 0.5;
% PData.Size(1) = ceil((SFormat.endDepth-SFormat.startDepth)/PData.pdeltaZ); % startDepth, endDepth and pdelta set PData.Size.
% PData.Size(2) = ceil((Trans.numelements*Trans.spacing)/PData.pdeltaX);
% PData.Size(3) = 1;      % single image page
% PData.Origin = [-Trans.spacing*(Trans.numelements-1)/2,0,SFormat.startDepth]; % x,y,z of upper lft crnr.

% Specify Media object.
clear Media;
reset_Phantom = 0;
pt1;
Media.function = 'move_Points';

% Specify Resources.
Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = 2^nextpow2(2*round(ceil(2*(RF_Points_Per_Wavelength*(end_RF_Depth/wavelength_in_mm)))/2));
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = 100;        % 100 frames used for RF cineloop.
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = 1024; % this is for maximum depth
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = 10;
Resource.DisplayWindow(1).Title = 'L7-4Flash_4B';
Resource.DisplayWindow(1).pdelta = 1/IQ_Points_Per_Wavelength;
ScrnSize = get(0,'ScreenSize');
DwWidth = ceil(PData.Size(2)*PData.pdeltaX/Resource.DisplayWindow(1).pdelta);
DwHeight = ceil(PData.Size(1)*PData.pdeltaZ/Resource.DisplayWindow(1).pdelta);
Resource.DisplayWindow(1).Position = [250,(ScrnSize(4)-(DwHeight+150))/2, ...  % lower left corner position
                                      DwWidth, DwHeight];
Resource.DisplayWindow(1).ReferencePt = [PData.Origin(1),PData.Origin(3)];  % 2D imaging is in the X,Z plane
Resource.DisplayWindow(1).Colormap = gray(256);

% Specify Transmit waveform structure. 
clear TW;
TW(1).type = 'parametric';
TW(1).Parameters = [18,17,2,1];   % A, B, C, D

% Specify TX structure array.  
clear TX;
TX.waveform = 1;            % use 1st TW structure.
TX.Origin = [0.0,0.0,0.0];  % flash transmit origin at (0,0,0).
TX.focus = 0;
TX.Steer = [0.0,0.0];       % theta, alpha = 0.
TX.Apod = ones(1,128);
TX.Delay = computeTXDelays(TX);

% Specify TGC Waveform structure.
TGC.CntrlPts = [400,490,550,610,670,730,790,850];
TGC.rangeMax = SFormat.endDepth;
TGC.Waveform = computeTGCWaveform(TGC);

% Specify Receive structure arrays -
%   endDepth - add additional acquisition depth to account for some channels
%              having longer path lengths.
%   InputFilter - The same coefficients are used for all channels. The
%              coefficients below give a broad bandwidth bandpass filter.
maxAcqLength = sqrt(SFormat.endDepth^2 + (Trans.numelements*Trans.spacing)^2) - SFormat.startDepth;
wlsPer128 = 128/(4*2); % wavelengths in 128 samples for 4 samplesPerWave
clear Receive;
Receive = repmat(struct('Apod', ones(1,Resource.Parameters.numRcvChannels), ...
                        'startDepth', SFormat.startDepth, ...
                        'endDepth', SFormat.startDepth + wlsPer128*ceil(maxAcqLength/wlsPer128), ...
                        'TGC', 1, ...
                        'bufnum', 1, ...
                        'framenum', 1, ...
                        'acqNum', 1, ...
                        'samplesPerWave', 4, ...
                        'mode', 0, ...
                        'InputFilter', [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494], ...
                        'callMediaFunc', 1),1,Resource.RcvBuffer(1).numFrames);
% - Set event specific Receive attributes.
for i = 1:Resource.RcvBuffer(1).numFrames
    Receive(i).framenum = i;
end

% Specify Recon structure arrays.
clear DMAControl;
clear Recon;
Recon = struct('senscutoff', 0.5, ...
               'pdatanum', 1, ...
               'rcvBufFrame', -1, ...
               'ImgBufDest', [1,-1], ...
               'RINums', 1);

% Define ReconInfo structures.
clear ReconInfo
ReconInfo = struct('mode', 0, ...          % replace amplitude.
                   'txnum', 1, ...
                   'rcvnum', 1, ...
                   'regionnum',0);

% Specify Process structure array.
pers = 30;
clear Process;
Process(1).classname = 'Image';
Process(1).method = 'imageDisplay';
Process(1).Parameters = {'imgbufnum',1,...   % number of buffer to process.
                         'framenum',-1,...   % (-1 => lastFrame)
                         'pdatanum',1,...    % number of PData structure to use
                         'norm',1,...        % normalization method(1 means fixed)
                         'pgain',1.0,...            % pgain is image processing gain
                         'persistMethod','simple',...
                         'persistLevel',pers,...
                         'interp',1,...      % method of interpolation (1=4pt interp)
                         'compression',0.5,...      % X^0.5 normalized to output word size
                         'reject',2,...
                         'mappingMode','full',...
                         'display',1,...      % display image after processing
                         'displayWindow',1,...
                         'extDisplay',1};

Process(2).classname = 'External';
Process(2).method = 'chanagetoCurrentFrameinImageProcess';
Process(2).Parameters = {};

% Specify SeqControl structure arrays.
clear SeqControl;
clear Event;
SeqControl(1).command = 'timeToNextAcq';
SeqControl(1).argument = 10000;  % 10000usec = 10msec (~ 100 fps)
SeqControl(2).command = 'returnToMatlab';
SeqControl(3).command = 'jump';
SeqControl(3).argument = 1;
nsc = 4; % nsc is count of SeqControl objects

n = 1; % n is count of Events

% Acquire all frames defined in RcvBuffer
currentFrame = 0; %To synchrnize the display code.
for i = 1:Resource.RcvBuffer(1).numFrames
    Event(n).info = 'acquisition';
    Event(n).tx = 1;         % use 1st TX structure.
    Event(n).rcv = i;        % use ith Rcv structure.
    Event(n).recon = 0;      % no reconstruction.
    Event(n).process = 2;    % no processing
    Event(n).seqControl = [1,nsc]; % use SeqControl struct defined below.
       SeqControl(nsc).command = 'transferToHost';
       nsc = nsc + 1;
    n = n+1;
    
    Event(n).info = 'Reconstruct'; 
    Event(n).tx = 0;         % no transmit
    Event(n).rcv = 0;        % no rcv
    Event(n).recon = 1;      % reconstruction
    Event(n).process = 1;    % processing
    if floor(i/5) == i/5     % Exit to Matlab every 5th frame 
        Event(n).seqControl = 2; % return to Matlab
    else
        Event(n).seqControl = 0;
    end
    n = n+1;
end

Event(n).info = 'Jump back to first event';
Event(n).tx = 0;        % no TX
Event(n).rcv = 0;       % no Rcv
Event(n).recon = 0;     % no Recon
Event(n).process = 0; 
Event(n).seqControl = 3; % jump command

% Save all the structures to a .mat file.
save('L7-4Flash_4B');
filename = 'L7-4Flash_4B';
VSX