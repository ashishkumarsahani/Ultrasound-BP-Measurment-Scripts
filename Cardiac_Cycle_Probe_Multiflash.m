Mcr_GuiHide = 1; %Control panel hide
Mcr_DisplayHide = 1; %Display window hide
extDisplay_On =1; %External display on

number_Of_Angles = 3; %Always set to odd
if (number_Of_Angles > 1), dtheta = (36*pi/180)/(number_Of_Angles-1); else dtheta = 0; end % set dtheta to range over +/- 18 degrees.

PRF = 4200;
timing_List_in_us = 0; 
push_Timing_Start_End = [0 0];
image_Pulse_TXnum = 1;
voltage_Levels = cardiac_Push_Voltage;
current_Voltage_Level_Index = 1;
curr_No_of_Sub_Pulses = number_Subpulses_in_Cardiac_Push;

ping_Pressure_List = zeros(total_No_of_Pings,1);
ping_Pressure_List_Index =1;

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

if(TGC_On ==0)
    TGC(1).Waveform = (TGC(1).Waveform*0 +0.001); %Remove TGC
end

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
Resource.RcvBuffer(1).rowsPerFrame = 2^nextpow2(2*round(ceil(2*(RF_Points_Per_Wavelength*(end_RF_Depth/wavelength_in_mm)))/2))*no_Frames_Per_Cardiac_Push*number_Of_Angles; %range is set to double the target distance.
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = total_No_of_Pings; % minimum size is 1 frame.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).rowsPerFrame = PData(1).Size(1,1); % this is for greatest depth
Resource.InterBuffer(1).colsPerFrame = PData.Size(2);
Resource.InterBuffer(1).numFrames = 1;  %one intermediate buffer needed.
Resource.InterBuffer(1).pagesPerFrame = 1;
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = PData(1).Size(1,1);
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = no_Frames_Per_Cardiac_Push*total_No_of_Pings;
Resource.ImageBuffer(1).pagesPerFrame = 1; 

Resource.VDAS.dmaTimeout = 200;

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
                        'callMediaFunc', 0),1,no_Frames_Per_Cardiac_Push*total_No_of_Pings);
                    
% - Set event specific Receive attributes.
for i = 1:no_Frames_Per_Cardiac_Push*total_No_of_Pings*number_Of_Angles
        Receive(i).Apod = ones(1, 128);
        Receive(i).startDepth = 0;
        Receive(i).endDepth = end_RF_Depth/wavelength_in_mm;
        Receive(i).TGC = 1; % Use the first TGC waveform defined above
        Receive(i).mode = 0;
        Receive(i).bufnum = 1;
        Receive(i).framenum = ceil(i/(no_Frames_Per_Cardiac_Push*number_Of_Angles));
        Receive(i).acqNum = mod(i-1,no_Frames_Per_Cardiac_Push*number_Of_Angles)+1;
        Receive(i).samplesPerWave = RF_Points_Per_Wavelength;
        Receive(i).InputFilter = [0.0036,0.0127,0.0066,-0.0881,-0.2595,0.6494];
        Receive(i).callMediaFunc = 1;
end

% Specify Recon structure arrays.
clear Recon;
Recon = repmat(struct('senscutoff', 0.6, ...
               'pdatanum', 1, ...
               'ImgBufDest', [1,-1], ...  % auto-increment ImageBuffer each recon
               'newFrameTimeout', -1,...
               'RINums', (1:number_Of_Angles)'), 1, no_Frames_Per_Cardiac_Push*total_No_of_Pings);

clear ReconInfo;
ReconInfo = repmat(struct('mode', 0, ...  % default accumulate IQ data.
                   'txnum', image_Pulse_TXnum, ...
                   'rcvnum', 1, ...
                   'pagenum',1,...
                   'regionnum', 0), 1, no_Frames_Per_Cardiac_Push*total_No_of_Pings*number_Of_Angles);

% - Set event specific Recon attributes.
for i = 1:number_Of_Angles*no_Frames_Per_Cardiac_Push*total_No_of_Pings
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

for i = 1:no_Frames_Per_Cardiac_Push*total_No_of_Pings
    Recon(i).ImgBufDest = [1,i];
    Recon(i).IntBufDest = [1,1];
    Recon(i).RINums = number_Of_Angles*(i-1) + (1:number_Of_Angles)';
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
SeqControl(5).command = 'timeToNextAcq'; %Time after the push end to first tracking image including the last pulse duration
SeqControl(5).argument = round((1000000/pings_per_Second));
SeqControl(6).command = 'returnToMatlab';
SeqControl(7).command = 'sync';
SeqControl(7).argument = 10E6; % Timeout

push_pulse_duration_us = (number_Of_Cycles_Per_SubPulse*64)/(5*2);
time_to_Next_Tracking_Image = 150; % Mimimum 143 us is reliable (Tested on scope)

time_us_between_push = push_pulse_duration_us+ gap_Between_Pulses_in_us; 
time_us_pushend2imagestart =  push_pulse_duration_us+ time_to_Next_Tracking_Image; %Time to first tracking image

SeqControl(8).command = 'timeToNextEB';
SeqControl(8).argument = time_us_between_push;%(time_us_between_push*1000)/200; %Time between pulses is push_pulse_duration_us + time_us_between_push

SeqControl(9).command = 'timeToNextAcq';%'noop'; %Time after the push end to first tracking image including the last pulse duration
SeqControl(9).argument = time_us_pushend2imagestart;%((time_us_pushend2imagestart)*1000)/200;

SeqControl(10).command = 'triggerOut';

SeqControl(11).command = 'timeToNextAcq'; %Smaller noop delay
SeqControl(11).argument = time_to_Next_Tracking_Image;  %value*200 ns

reference_To_Push_Delay = time_to_Next_Tracking_Image;
SeqControl(12).command = 'timeToNextEB'; %For accurate timing for reference frame to push pulse delivery
SeqControl(12).argument = reference_To_Push_Delay; 

SeqControl(13).command = 'sync';
SeqControl(13).argument = ceil((1100000/pings_per_Second)); % Timeout

seq_Count = 14; 
event_Count = 2;
packet_Time = (number_Of_Angles-1)*time_to_Next_Tracking_Image+reference_To_Push_Delay+time_us_between_push*(curr_No_of_Sub_Pulses-1) + time_us_pushend2imagestart+ (no_Frames_Per_Cardiac_Push-2)*time_to_Next_Tracking_Image*number_Of_Angles;
SeqControl(5).argument = round((1000000/pings_per_Second)-packet_Time);

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
Event(event_Count).seqControl = 7;
event_Count = event_Count+1;

%%%%%Live push view%%%%%
for i=1:100
    for j =1:number_Of_Angles
        Event(event_Count).info = 'Acquire the live image';
        Event(event_Count).tx = j; % use 1st TX structure.
        Event(event_Count).rcv = j; % use 1st Rcv structure.
        Event(event_Count).recon = 0; % no reconstruction.
        Event(event_Count).process = 0; % read voltage here
        Event(event_Count).seqControl = [11]; %Flash angles delay 150us
        event_Count = event_Count+1;
    end
    
    Event(event_Count-1).info = 'Recon and show image';
    Event(event_Count-1).recon = 1; % no reconstruction.
    Event(event_Count-1).process = 7; % read voltage here
    Event(event_Count-1).seqControl = [seq_Count 2]; %Flash angles delay
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
Event(event_Count).seqControl = 7;
event_Count = event_Count+1;

Event(event_Count).info = 'Start Time stamped pressure acquisition';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 5; % read pressure here
Event(event_Count).seqControl = [6]; %return to matlab
event_Count = event_Count+1;

%Sync hardware and software
Event(event_Count).info = 'Sync HW and SW';
Event(event_Count).tx = 0;
Event(event_Count).rcv = 0;
Event(event_Count).recon = 0;
Event(event_Count).process = 0; %Set voltage and move the voltage pointer to the next lower voltage
Event(event_Count).seqControl = 13;
event_Count = event_Count+1;


pressure_Time_List_us = [0];

for l = 1:total_No_of_Pings 
%%%%%Reference image%%%%%
image_Pulse_Num = ceil(number_Of_Angles/2);
for j =1:number_Of_Angles
    Event(event_Count).info = 'Acquire the ref. image';
    Event(event_Count).tx = j; % use 1st TX structure.
    Event(event_Count).rcv = j + (l-1)*(no_Frames_Per_Cardiac_Push*number_Of_Angles); % use 1st Rcv structure.
    Event(event_Count).recon = 0; % no reconstruction.
    Event(event_Count).process = 0; % read pressure here
    Event(event_Count).seqControl = [11]; %Reference flash delay
    event_Count = event_Count+1;
end
Event(event_Count).seqControl = [12]; %Reference frame to push pulse delay

timing_List_in_us(1 + (l-1)*(no_Frames_Per_Cardiac_Push)) = time_to_Next_Tracking_Image*((l-1)*(no_Frames_Per_Cardiac_Push*number_Of_Angles))+(l-1)*round(1000000/pings_per_Second);
pressure_Time_List(l) = (l-1)*round(1000000/pings_per_Second);

%%%%%%%Trigger for oscilloscipe test%%%%%%%%%%
Event(event_Count).info = 'Send trigger out';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % no reconstruction.
Event(event_Count).process = 0; % read voltage here
Event(event_Count).seqControl = [10]; %trigger out
event_Count = event_Count+1;

%%%%%%%Push pulse%%%%%%%%%%
for k = 1:curr_No_of_Sub_Pulses
    Event(event_Count).info = ['Push sequence sub-pulse no.:',num2str(k)];
    Event(event_Count).tx = push_TX_Num; % use push TX structure.
    Event(event_Count).rcv = 0; % use 2nd Rcv structure to see what exactly happens during the push burst
    Event(event_Count).recon = 0; % no reconstruction.
    Event(event_Count).process = 0; % no processing
    Event(event_Count).seqControl = 8; %delay between each subpulse including the pulse duration and gap
    event_Count = event_Count+1;         
end
Event(event_Count-1).seqControl = [9]; %Delay after the last push pulse.

% Acquire image.
for i = 2:no_Frames_Per_Cardiac_Push
    for j =1:number_Of_Angles
        Event(event_Count).info = 'Acquire the ref. image';
        Event(event_Count).tx = j; % use 1st TX structure.
        Event(event_Count).rcv = j+(i-1)*number_Of_Angles + (l-1)*(no_Frames_Per_Cardiac_Push*number_Of_Angles); % use 1st Rcv structure.
        Event(event_Count).recon = 0; % no reconstruction.
        Event(event_Count).process = 0; % read pressure here
        Event(event_Count).seqControl = [11]; %Reference flash delay
        event_Count = event_Count+1;
    end
    timing_List_in_us((l-1)*(no_Frames_Per_Cardiac_Push)+ i) = timing_List_in_us((l-1)*(no_Frames_Per_Cardiac_Push)+ i-1)+time_to_Next_Tracking_Image*number_Of_Angles;
end

Event(event_Count-1).seqControl = [seq_Count 5]; % Transfer to host and delay till next push
SeqControl(seq_Count).command = 'transferToHost';
seq_Count = seq_Count+1;
end

Event(event_Count).info = 'Sync Hardware and Software';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 0; % Show images
Event(event_Count).seqControl = 7; % pause after image show
event_Count = event_Count + 1;

Event(event_Count).info = 'Pressure read';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 6; % Show images
Event(event_Count).seqControl = 6; % pause after image show
event_Count = event_Count + 1;

for i = 1:total_No_of_Pings*no_Frames_Per_Cardiac_Push
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

Event(event_Count).info = 'Exit';
Event(event_Count).tx = 0; % use 1st TX structure.
Event(event_Count).rcv = 0; % use 1st Rcv structure.
Event(event_Count).recon = 0; % reconstruction.
Event(event_Count).process = 4; % 
Event(event_Count).seqControl = 0; % no processing

event_Count = event_Count + 1;

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
                         'extDisplay',extDisplay_On};

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

frame_Count = 1;
for i = 7:7+total_No_of_Pings*no_Frames_Per_Cardiac_Push - 1
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
                             'extDisplay',extDisplay_On};
   frame_Count = frame_Count+1;
end
% Save all the structures to a .mat file.
filename = 'Cardiac_Cycle_Mltiflash_Mat.mat';
save(filename);
VSX

