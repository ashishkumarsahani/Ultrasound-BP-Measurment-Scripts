Mcr_GuiHide = 1; %Control panel hide
Mcr_DisplayHide = 1; %Display window hide
number_Of_Angles =5;

if (number_Of_Angles > 1), dtheta = 0.5*(36*pi/180)/(number_Of_Angles-1); else dtheta = 0; end % set dtheta to range over +/- 18 degrees.

PRF = 4200;
timing_List_in_us = 0; 
push_Timing_Start_End = [0 0];
image_Pulse_TXnum = 1;
current_Voltage_Level_Index = 1;

clear Media;
reset_Phantom = 0;
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
%     if(number_Of_Angles ==1)
%         TX(n).Steer = [((36*pi/180)/3),0.0];
%     end
    TX(n).Delay = computeTXDelays(TX(n));
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
Resource.RcvBuffer(1).rowsPerFrame = number_Of_Angles*2^nextpow2(2*round(ceil(2*(RF_Points_Per_Wavelength*(end_RF_Depth/wavelength_in_mm)))/2))* (num_of_Frames_Per_Push_Cycle); %range is set to double the target distance.
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = length(voltage_Levels)*length(time_List); % minimum size is 1 frame.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).rowsPerFrame = PData(1).Size(1,1); % this is for greatest depth
Resource.InterBuffer(1).colsPerFrame = PData.Size(2);
Resource.InterBuffer(1).numFrames = num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List);  %one intermediate buffer needed.
Resource.InterBuffer(1).pagesPerFrame = 1;
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = PData(1).Size(1,1);
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List);
Resource.ImageBuffer(1).pagesPerFrame = 1; 

if(number_Of_Angles ==1)
    Resource.VDAS.dmaTimeout = 400;
else
    Resource.VDAS.dmaTimeout = 100*number_Of_Angles;
end

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
               'RINums', (1:number_Of_Angles)'), 1, num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List));

clear ReconInfo;
ReconInfo = repmat(struct('mode', 4, ...  % default accumulate IQ data.
                   'txnum', image_Pulse_TXnum, ...
                   'rcvnum', 1, ...
                   'pagenum',1,...
                   'regionnum', 0), 1, number_Of_Angles*num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List));

% - Set event specific Recon attributes.
for i = 1:number_Of_Angles*num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List)
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

for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List)
    Recon(i).ImgBufDest = [1,i];
    Recon(i).IntBufDest = [1,i];
    Recon(i).RINums = number_Of_Angles*(i-1) + (1:number_Of_Angles)';
    if(i>1)
        Recon(i).newFrameTimeout= 1;
    end
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
                        'callMediaFunc', 0),1,num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List)*number_Of_Angles);
                    
% - Set event specific Receive attributes.
for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List)*number_Of_Angles
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

SeqControl(2).command = 'noop';
SeqControl(2).argument = 524287; % # Wait 102 milliseconds 
SeqControl(3).command = 'jump'; % jump back to start.
SeqControl(3).argument = 3;
SeqControl(4).command = 'timeToNextAcq';  % This sequence controls the time between the flash angles if any
interFrameTiming = 100000;   %100 ms between flash angles
SeqControl(4).argument = interFrameTiming;  
SeqControl(5).command = 'timeToNextAcq';  % time between push and first frame
SeqControl(5).argument = interFrameTiming;  %Not used
SeqControl(6).command = 'returnToMatlab';
SeqControl(7).command = 'sync';
SeqControl(7).argument = 30E6; % Timeout

push_pulse_duration_us = (number_Of_Cycles_Per_SubPulse*64)/(5*2);
time_us_between_push = gap_Between_Pulses_in_us; 
time_us_pushend2imagestart =  40; %Time to first tracking image

SeqControl(8).command = 'noop';
SeqControl(8).argument = (time_us_between_push*1000)/200; %Time between pulses is push_pulse_duration_us + time_us_between_push

SeqControl(9).command = 'noop'; %Time after the push end to first tracking image including the last pulse duration
SeqControl(9).argument = ((time_us_pushend2imagestart)*1000)/200;

% SeqControl(9).command = 'noop'; %Time after the push end to first tracking image including the last pulse duration
% SeqControl(9).argument = round(time_us_pushend2imagestart*1000/200);

SeqControl(10).command = 'triggerOut';

time_to_Next_Tracking_Image = 40;
SeqControl(11).command = 'noop'; %Smaller noop delay
SeqControl(11).argument = (time_to_Next_Tracking_Image*1000)/200;  %value*200 ns

timing_List_in_us(1) = 0; % Time of reference frame
push_Timing_Start_End(1) = SeqControl(11).argument/1000; %push delay after reference image microseconds 
push_Timing_Start_End(2) = push_Timing_Start_End(1) + time_List(end)*push_pulse_duration_us - time_us_between_push; %Total time of push pulses
timing_List_in_us(2) = push_Timing_Start_End(2); %Time of push pulse frame (Not used as this frame is not formed)
timing_List_in_us(3) = push_Timing_Start_End(2) + time_us_pushend2imagestart; %Time of the first tracking image


if(num_of_Frames_Per_Push_Cycle> 3)
    for i = 4:num_of_Frames_Per_Push_Cycle
        timing_List_in_us(i) = timing_List_in_us(i-1) + time_to_Next_Tracking_Image;
    end
end
seq_Count = 12; 
event_Count = 2;

Event(event_Count).info = 'Delay for Push Power Supply to Charge Up';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; 
Event(event_Count).seqControl = 2;
event_Count = event_Count+1;

for l = 1:length(voltage_Levels)*length(time_List)
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
Event(event_Count).seqControl = 7;
event_Count = event_Count+1;

%%%%%%%Wait%%%%%%
Event(event_Count).info = 'Wait for some time for tube to settle from last push';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % read voltage here
Event(event_Count).seqControl = [2 2 2]; %noop
event_Count = event_Count+1;

%%%%%Reference image%%%%%
for image_Pulse_Num = 1:number_Of_Angles
        Event(event_Count).info = 'Acquire the ref. image';
        Event(event_Count).tx = image_Pulse_Num; % use 1st TX structure.
        Event(event_Count).rcv = (l-1)*num_of_Frames_Per_Push_Cycle*number_Of_Angles + image_Pulse_Num; % use 1st Rcv structure.
        Event(event_Count).recon = 0; % no reconstruction.
        Event(event_Count).process = 3; % read voltage here
        Event(event_Count).seqControl = 0; %no delay between flash angles required here
        event_Count = event_Count+1;
end
Event(event_Count-1).seqControl = 11; %Delay till push (200 us here)

% Specify sequence events.
for i = 3:num_of_Frames_Per_Push_Cycle
    %%%%%%%Push Pulses%%%%%%%%%%%
    Event(event_Count).info = 'Send trigger out';
    Event(event_Count).tx = 0; % use 1st TX structure.
    Event(event_Count).rcv = 0; % use 1st Rcv structure.
    Event(event_Count).recon = 0; % no reconstruction.
    Event(event_Count).process = 0; % read voltage here
    Event(event_Count).seqControl = 10; %no delay between flash angles required here
    event_Count = event_Count+1;
    if(i ==3) %Only push before the third frame
        curr_No_of_Sub_Pulses = 1;
        if(length(time_List)>1)
            curr_No_of_Sub_Pulses = time_List(l);
        else
            curr_No_of_Sub_Pulses = time_List;
        end
        for k = 1:curr_No_of_Sub_Pulses
            Event(event_Count).info = 'Push Pulse Delivery';
            Event(event_Count).tx = push_TX_Num; % use push TX structure.
            Event(event_Count).rcv = 0; % use 2nd Rcv structure to see what exactly happens during the push burst
            Event(event_Count).recon = 0; % no reconstruction.
            Event(event_Count).process = 0; % no processing
            Event(event_Count).seqControl = 8; % 4us delay for each push pulse
            event_Count = event_Count+1;         
        end
        Event(event_Count-1).seqControl = 9; % 40 us delay after the last push pulse.
    end
    for image_Pulse_Num = 1:number_Of_Angles 
        Event(event_Count).info = ['RF Data frame ',num2str(i-3+1), 'after the push'];
        Event(event_Count).tx = image_Pulse_Num; % use 1st TX structure.
        Event(event_Count).rcv = (l-1)*num_of_Frames_Per_Push_Cycle*number_Of_Angles + (i-1)*number_Of_Angles + image_Pulse_Num; % use 1st Rcv structure.
        Event(event_Count).recon = 0; % no reconstruction.
        Event(event_Count).process = 0; % no processing
        Event(event_Count).seqControl = [2]; % Wait noop between flash angle pushes
        event_Count = event_Count + 1;
    end
    Event(event_Count-1).seqControl = [11]; % Wait 40us between subsequent tracking frames
end
Event(event_Count-1).seqControl = 0;
Event(event_Count-1).seqControl = [seq_Count]; % PRT delay
SeqControl(seq_Count).command = 'transferToHost';
seq_Count = seq_Count+1;
end

currentFrame = 0;
for i = 1:num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List)
    if(i~=2)
        Event(event_Count).info = 'Reconstruction';
        Event(event_Count).tx = 0; % use 1st TX structure.
        Event(event_Count).rcv = 0; % use 1st Rcv structure.
        Event(event_Count).recon = i; % reconstruction.
        Event(event_Count).process = 6+i; % Show images
        Event(event_Count).seqControl = 0; % pause after image show

        event_Count = event_Count + 1;

        Event(event_Count).info = 'Return to matlab';
        Event(event_Count).tx = 0; % use 1st TX structure.
        Event(event_Count).rcv = 0; % use 1st Rcv structure.
        Event(event_Count).recon = 0; % reconstruction.
        Event(event_Count).process = 0; % 
        Event(event_Count).seqControl = 6; % no processing

        event_Count = event_Count + 1;
    end
end
Event(event_Count-1).process = 5;
 
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
Process(4).method = 'reset_VDAS_Timeout';
Process(4).Parameters = {};

Process(5).classname = 'External';
Process(5).method = 'reconstruction_Finished';
Process(5).Parameters = {};

Process(6).classname = 'External';
Process(6).method = 'getReadytoFocus';
Process(6).Parameters = {};

frame_Count = 1;
for i = 7:7+num_of_Frames_Per_Push_Cycle*length(voltage_Levels)*length(time_List) - 1
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
filename = 'pushSequenceMat.mat';
save(filename);
VSX

