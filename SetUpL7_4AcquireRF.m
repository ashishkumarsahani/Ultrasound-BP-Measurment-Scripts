% Copyright 2001-2013 Verasonics, Inc.  All world-wide rights and remedies under all intellectual property laws and industrial property laws are reserved.  Verasonics Registered U.S. Patent and Trademark Office.
%
% File name SetUpL7_4AcquireRF.m
%  - Asynchronous acquisition into multiple RcvBuffer frames.
%
% last update 03-17-2013

clear all

% Specify system parameters
Resource.Parameters.numTransmit = 128;      % no. of transmit channels (2 brds).
Resource.Parameters.numRcvChannels = 128;    % no. of receive channels (2 brds).
Resource.Parameters.speedOfSound = 1540;    % speed of sound in m/sec
Resource.Parameters.fakeScanhead = 1;       % optional (if no L7-4)
Resource.Parameters.simulateMode = 0;       % runs script in simulate mode

% Specify media points
Media.MP(1,:) = [0,0,100,1.0]; % [x, y, z, reflectivity]

% Specify Trans structure array.
Trans.name = 'L7-4';
Trans = computeTrans(Trans);  % L7-4 transducer is 'known' transducer.

% Specify Resource buffers.
Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = 4096;  % this allows for 1/4 maximum range
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = 10;       % allocate 10 frames.

% Specify Transmit waveform structure. 
TW(1).type = 'parametric';
TW(1).Parameters = [18,17,2,1];   % A, B, C, D
Apodaziation = zeros(1,128);
Apodaziation(1:5) = 1;
Apodaziation(end-4:end) =1;
% Specify TX structure array.  
TX(1).waveform = 1;            % use 1st TW structure.
TX(1).focus = 0;
TX(1).Apod = Apodaziation;
TX(1).Delay = computeTXDelays(TX(1));

% Specify TGC Waveform structure.
TGC(1).CntrlPts = [500,590,650,710,770,830,890,950];
TGC(1).rangeMax = 200;
TGC(1).Waveform = computeTGCWaveform(TGC);

% Specify Receive structure array -
Receive = repmat(struct(...
                'Apod', Apodaziation, ...
                'startDepth', 0, ...
                'endDepth', 200, ...
                'TGC', 1, ...
                'mode', 0, ...
                'bufnum', 1, ...
                'framenum', 1, ...
                'acqNum', 1, ...
                'samplesPerWave', 4, ...
                'InputFilter',[0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494]),...
                1,2*Resource.RcvBuffer(1).numFrames);
            
% - Set event specific Receive attributes.
for i = 1:Resource.RcvBuffer(1).numFrames
    % -- 1st synthetic aperture acquisition.
    Receive(2*i-1).Apod(1:Resource.Parameters.numRcvChannels) = 1;
    Receive(2*i-1).framenum = i;
    Receive(2*i-1).acqNum = 1;
    % -- 2nd synthetic aperture acquisition.
    Receive(2*i).Apod = zeros(1, 128);
    Receive(2*i).Apod(65:128) = 1;
    Receive(2*i).framenum = i;
    Receive(2*i).acqNum = 2;   % two acquisitions per frame 
end

% Specify an external processing event.
Process(1).classname = 'External';
Process(1).method = 'myProcFunction';
Process(1).Parameters = {'srcbuffer','receive',... % name of buffer to process.
                         'srcbufnum',1,...
                         'srcframenum',-1,... % process the most recent frame.
                         'dstbuffer','none'};

% Specify sequence events.
SeqControl(1).command = 'timeToNextAcq';
SeqControl(1).argument = 200;
SeqControl(2).command = 'timeToNextAcq';
SeqControl(2).argument = 9800;
SeqControl(3).command = 'jump';
SeqControl(3).argument = 1;
nsc = 4; % start index for new SeqControl

n = 1;   % start index for Events
for i = 1:Resource.RcvBuffer(1).numFrames
	Event(n).info = 'Acquire RF Data for 1st half of aperture.';
	Event(n).tx = 1;         % use 1st TX structure.
	Event(n).rcv = 2*i-1;    % use 1st Rcv structure of frame.
	Event(n).recon = 0;      % no reconstruction.
	Event(n).process = 0;    % no processing
	Event(n).seqControl = 1; % wait 200 usec
	n = n+1;

	Event(n).info = 'Acquire RF Data for 2nd half of aperture.';
	Event(n).tx = 1;         % use 1st TX structure.
	Event(n).rcv = 2*i;      % use 2nd Rcv structure of frame.
	Event(n).recon = 0;      % no reconstruction.
	Event(n).process = 0;    % no processing
	Event(n).seqControl = [2,nsc]; % set wait time and transfer data
	   SeqControl(nsc).command = 'transferToHost';
	   nsc = nsc + 1;
      n = n+1;

	Event(n).info = 'Call external Processing function.';
	Event(n).tx = 0;         % no TX structure.
	Event(n).rcv = 0;        % no Rcv structure.
	Event(n).recon = 0;      % no reconstruction.
	Event(n).process = 1;    % call processing function
	Event(n).seqControl = 0; 
	n = n+1;
end
Event(n).info = 'Jump back to Event 1.';
Event(n).tx = 0;         % no TX structure.
Event(n).rcv = 0;        % no Rcv structure.
Event(n).recon = 0;      % no reconstruction.
Event(n).process = 0;    % no processing
Event(n).seqControl = 3; % jump back to Event 1.

% - Create UI controls for channel selection
nr = Resource.Parameters.numRcvChannels;
UI(1).Control = {'UserB1','Style','VsSlider',... 
                 'Label','Plot Channel',...
                 'SliderMinMaxVal',[1,64,32],...
                 'SliderStep', [1/nr,8/nr],...
                 'ValueFormat', '%3.0f'};
UI(1).Callback = {'assignin(''base'',''myPlotChnl'',round(UIValue))'};                 
EF(1).Function = text2cell('SetUpL7_4AcquireRF.m','%EF#1');

% Save all the structures to a .mat file.
save('L7-4AcquireRF');
return 

%EF#1
myProcFunction(RData) 
persistent myHandle  
% If ?myPlotChnl? exists, read it for the channel to plot.
if evalin('base','exist(''myPlotChnl'',''var'')')
    channel = evalin('base','myPlotChnl');
else
    channel = 32;  % Channel no. to plot
end
% Create the figure if it doesn?t exist.
if isempty(myHandle)||~ishandle(myHandle)
    figure;
    myHandle = axes('XLim',[0,1500],'YLim',[-100 100], ...
                    'NextPlot','replacechildren');
end
% Plot the RF data. 
cla(myHandle)
plot(myHandle,RData(:,3));
hold on
plot(myHandle,RData(:,126),'r');
drawnow
%EF#1
