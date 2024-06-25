% Copyright 2001-2013 Verasonics, Inc.  All world-wide rights and remedies under all intellectual property laws and industrial property laws are reserved.  Verasonics Registered U.S. Patent and Trademark Office.
%
% File name SetUpL7_4FlashAngles_4B.m:
% Generate .mat Sequence Object file for L7-4 Linear array flash transmit, with
% multiple steering angles.
% 128 transmit and 128 receive channels are used.
%
% last update: 03-29-2013

clear all
num_of_Frames_Per_Push_Cycle = 30;
reset_Phantom = 1;
wavelength_in_mm = 0.308;

na = 7;      % Set na = number of angles.
if (na > 1), dtheta = (36*pi/180)/(na-1); else dtheta = 0; end % set dtheta to range over +/- 18 degrees.

% Specify system parameters.
Resource.Parameters.connector = 1;
Resource.Parameters.numTransmit = 128;  % number of transmit channels.
Resource.Parameters.numRcvChannels = 128;  % number of receive channels.
Resource.Parameters.speedOfSound = 1540;
Resource.Parameters.simulateMode = 1; % 0 means no simulation, if hardware is present.
%  Resource.Parameters.simulateMode = 1 forces simulate mode, even if hardware is present.
%  Resource.Parameters.simulateMode = 2 stops sequence and processes RcvData continuously.

% Specify Trans structure array.
Trans.name = 'L7-4';
Trans = computeTrans(Trans);  % L7-4 transducer is 'known' transducer so we can use computeTrans.
Trans.maxHighVoltage = 50;  % set maximum high voltage limit for pulser supply.

% Specify SFormat structure array.
SFormat.transducer = 'L7-4';     % 128 element linear array with 1.0 lambda spacing
SFormat.scanFormat = 'RLIN';     % rectangular linear array scan
SFormat.radius = 0;              % ROC for curved lin. or dist. to virt. apex
SFormat.theta = 0;
SFormat.numRays = 1;      % no. of Rays (1 for Flat Focus)
SFormat.FirstRayLoc = [0,0,0];   % x,y,z
SFormat.rayDelta = 128*Trans.spacing;  % spacing in radians(sector) or dist. between rays (wvlnghts)
SFormat.startDepth = 5;   % Acquisition depth in wavelengths
SFormat.endDepth = 192;   % This should preferrably be a multiple of 128 samples.

% Specify PData structure array.
PData.sFormat = 1;        % use first SFormat structure.
PData.pdeltaX = 1.0;
PData.pdeltaZ = 0.5;
PData.Size(1,1) = ceil((SFormat.endDepth-SFormat.startDepth)/PData.pdeltaZ); % range, origin and pdelta set PData.Size.
PData.Size(1,2) = ceil((Trans.numelements*Trans.spacing)/PData.pdeltaX);
PData.Size(1,3) = 1;      % single image page
PData.Origin = [-Trans.spacing*(Trans.numelements-1)/2,0,SFormat.startDepth]; % x,y,z of uppr lft crnr.

% Specify Media object.
pt1;
Media.function = 'move_Points';

% Specify Resources.
Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = na*6144; % this size allows for maximum range
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = 30;    % 30 frames stored in RcvBuffer.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).numFrames = 1;   % one intermediate buffer needed.
Resource.InterBuffer(1).rowsPerFrame = 1024;
Resource.InterBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = 1024; % this is for maximum depth
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = 10;
Resource.DisplayWindow(1).Title = 'L7-4FlashAngles_4B';
Resource.DisplayWindow(1).pdelta = 0.3;
Resource.DisplayWindow(1).Position = [250,150, ...
    ceil(PData.Size(2)*PData.pdeltaX/Resource.DisplayWindow(1).pdelta), ... % width
    ceil(PData.Size(1)*PData.pdeltaZ/Resource.DisplayWindow(1).pdelta)];    % height
Resource.DisplayWindow(1).ReferencePt = [PData.Origin(1),PData.Origin(3)]; % 2D imaging is in the X,Z plane
Resource.DisplayWindow(1).Colormap = gray(256);

% Specify Transmit waveform structure.  
TW.type = 'parametric';
TW.Parameters = [18,17,2,1];   % A, B, C, D

% Specify TX structure array.
TX = repmat(struct('waveform', 1, ...
                   'Origin', [0.0,0.0,0.0], ...
                   'Apod', kaiser(Resource.Parameters.numTransmit,1)', ...
                   'focus', 0.0, ...
                   'Steer', [0.0,0.0], ...
                   'Delay', zeros(1,Trans.numelements)), 1, na);
% - Set event specific TX attributes.
if fix(na/2) == na/2       % if na even
    startAngle = (-(fix(na/2) - 1) - 0.5)*dtheta;
else
    startAngle = -fix(na/2)*dtheta;
end
for n = 1:na   % na transmit events
    TX(n).Steer = [(startAngle+(n-1)*dtheta),0.0];
    TX(n).Delay = computeTXDelays(TX(n));
end

% Specify TGC Waveform structure.
TGC.CntrlPts = [400,550,650,710,770,830,890,950];
TGC.rangeMax = SFormat.endDepth;
TGC.Waveform = computeTGCWaveform(TGC);

% Specify Receive structure arrays. 
% - We need 2*na Receives for every frame.
maxAcqLength = sqrt(SFormat.endDepth^2 + (Trans.numelements*Trans.spacing)^2) - SFormat.startDepth;
wlsPer128 = 128/(4*2); % wavelengths in 128 samples for 4 samplesPerWave
Receive = repmat(struct('Apod', ones(1,Trans.numelements), ...
                        'startDepth', SFormat.startDepth, ...
                        'endDepth', SFormat.startDepth + wlsPer128*ceil(maxAcqLength/wlsPer128), ...
                        'TGC', 1, ...
                        'bufnum', 1, ...
                        'framenum', 1, ...
                        'acqNum', 1, ...
                        'samplesPerWave', 4, ...
                        'mode', 0, ...
                        'InputFilter', [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494], ...
                        'callMediaFunc', 0), 1, na*Resource.RcvBuffer(1).numFrames);
% - Set event specific Receive attributes for each frame.
for i = 1:Resource.RcvBuffer(1).numFrames
    Receive(na*(i-1)+1).callMediaFunc = 1;
    for j = 1:na
        Receive(na*(i-1)+j).framenum = i;
        Receive(na*(i-1)+j).acqNum = j;
    end
end

% Specify Recon structure arrays.
% - We need one Recon structure which will be used for each frame. 
Recon = struct('senscutoff', 0.6, ...
               'pdatanum', 1, ...
               'rcvBufFrame',-1, ...
               'IntBufDest', [1,1], ...
               'ImgBufDest', [1,-1], ...
               'RINums',(1:na)');

% Define ReconInfo structures.
% We need 2*na ReconInfo structures for 2-1 synthetic aperture and na steering angles.
ReconInfo = repmat(struct('mode', 4, ...  % default is to accumulate IQ data.
                   'txnum', 1, ...
                   'rcvnum', 1, ...
                   'regionnum', 0), 1, na);
% - Set specific ReconInfo attributes.
ReconInfo(1).mode = 3; % replace IQ data
for j = 1:na  % For each row in the column
    ReconInfo(j).txnum = j;
    ReconInfo(j).rcvnum = j;
end
ReconInfo(na).mode = 5; % accum and detect        

% Specify Process structure array.
pers = 20;
Process(1).classname = 'Image';
Process(1).method = 'imageDisplay';
Process(1).Parameters = {'imgbufnum',1, ...   % number of buffer to process.
                         'framenum',-1, ...   % frame number in src buffer (-1 => lastFrame)
                         'pdatanum',1, ...    % number of PData structure (defines output figure).
                         'norm',1, ...        % normalization method(1 means fixed)
                         'pgain',1.0, ...            % pgain is image processing gain
                         'persistMethod','simple', ...
                         'persistLevel',pers, ...
                         'interp',1, ...      % method of interpolation (1=4pt interp)
                         'compression',0.5, ...      % X^0.5 normalized to output word size
                         'reject',2,...       % reject level 
                         'mappingMode','full', ...
                         'display',1, ...     % display image after processing
                         'displayWindow',1};

% Specify SeqControl structure arrays.
SeqControl(1).command = 'jump'; % jump back to start
SeqControl(1).argument = 1;
SeqControl(2).command = 'timeToNextAcq';  % time between synthetic aperture acquisitions
SeqControl(2).argument = 160;  % 160 usec
SeqControl(3).command = 'timeToNextAcq';  % time between frames
SeqControl(3).argument = 20000;  % 20 msec
SeqControl(4).command = 'returnToMatlab';
nsc = 5; % nsc is count of SeqControl objects

% Specify Event structure arrays.
n = 1;
for i = 1:Resource.RcvBuffer(1).numFrames
    for j = 1:na                 % Acquire frame
        Event(n).info = 'Acquire angles';
        Event(n).tx = j;   % use next TX structure.
        Event(n).rcv = na*(i-1)+j;   
        Event(n).recon = 0;      % no reconstruction.
        Event(n).process = 0;    % no processing
        Event(n).seqControl = 2;
        n = n+1;
    end
    Event(n-1).seqControl = [3,nsc]; % modify last acquisition Event's seqControl
      SeqControl(nsc).command = 'transferToHost'; % transfer frame to host buffer
      nsc = nsc+1;

    Event(n).info = 'recon and process'; 
    Event(n).tx = 0;         % no transmit
    Event(n).rcv = 0;        % no rcv
    Event(n).recon = 1;      % reconstruction
    Event(n).process = 1;    % process
    if floor(i/5) == i/5     % Exit to Matlab every 5th frame reconstructed 
        Event(n).seqControl = 4;
    else
        Event(n).seqControl = 0;
    end
    n = n+1;
end

Event(n).info = 'Jump back';
Event(n).tx = 0;        % no TX
Event(n).rcv = 0;       % no Rcv
Event(n).recon = 0;     % no Recon
Event(n).process = 0; 
Event(n).seqControl = 1;


% User specified UI Control Elements
% - Sensitivity Cutoff
UI(1).Control =  {'UserB7','Style','VsSlider','Label','Sens. Cutoff',...
                  'SliderMinMaxVal',[0,1.0,Recon(1).senscutoff],...
                  'SliderStep',[0.025,0.1],'ValueFormat','%1.3f'};
UI(1).Callback = text2cell('%-UI#1Callback');

% - Range Change
UI(2).Control = {'UserA1','Style','VsSlider','Label','Range',...
                 'SliderMinMaxVal',[64,320,SFormat.endDepth],'SliderStep',[0.1,0.2],'ValueFormat','%3.0f'};
UI(2).Callback = text2cell('%-UI#2Callback');

% Specify factor for converting sequenceRate to frameRate.
frameRateFactor = 5;

% Save all the structures to a .mat file.
save('L7-4FlashAngles_4B');

return


% **** Callback routines to be converted by text2cell function. ****
%-UI#1Callback - Sensitivity cutoff change
ReconL = evalin('base', 'Recon');
for i = 1:size(ReconL,2)
    ReconL(i).senscutoff = UIValue;
end
assignin('base','Recon',ReconL);
Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'Recon'};
assignin('base','Control', Control);
return
%-UI#1Callback

%-UI#2Callback - Range change
simMode = evalin('base','Resource.Parameters.simulateMode');
% No range change if in simulate mode 2.
if simMode == 2
    set(hObject,'Value',evalin('base','SFormat.endDepth'));
    return
end
range = UIValue;
assignin('base','range',range);
SFormat = evalin('base','SFormat');
SFormat.endDepth = range;
assignin('base','SFormat',SFormat);
evalin('base','PData.Size(1) = ceil((SFormat.endDepth-SFormat.startDepth)/PData.pdeltaZ);');
evalin('base','[PData.Region,PData.numRegions] = createRegions(PData);');
evalin('base','Resource.DisplayWindow(1).Position(4) = ceil(PData.Size(1)*PData.pdeltaZ/Resource.DisplayWindow(1).pdelta);');
Receive = evalin('base', 'Receive');
Trans = evalin('base', 'Trans');
maxAcqLength = sqrt(range^2 + (Trans.numelements*Trans.spacing)^2)-SFormat.startDepth;
wlsPer128 = 128/(4*2);
for i = 1:size(Receive,2)
    Receive(i).endDepth = SFormat.startDepth + wlsPer128*ceil(maxAcqLength/wlsPer128);
end
assignin('base','Receive',Receive);
evalin('base','TGC.rangeMax = SFormat.endDepth;');
evalin('base','TGC.Waveform = computeTGCWaveform(TGC);');
Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'SFormat','PData','Receive','Recon','DisplayWindow','ImageBuffer'};
assignin('base','Control', Control);
assignin('base', 'action', 'displayChange');
return
%-UI#2Callback
