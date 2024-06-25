function Display_and_Measurement_Interface
%GUI for measurement of data obtained from Verasonics
evalin('base', 'clear all');
measurement = struct;
cardiac_Cycle_Measurement = struct;
PWV_Measurement = struct;

num_of_Pulses_per_Push = 10;
num_of_Frames_Per_Push_Cycle = 3;
points_Per_Wavelength = 4;
points_Per_Wavelength_in_Image = 4;
transducer_Frequency_in_Hz = 5000000;
speed_Of_Sound = 1540;
waveLength =  1000*speed_Of_Sound/transducer_Frequency_in_Hz; 
center_of_Vision_mm = 18; %The code doesn't miss frames for a setting of about 85 wavelengths. 
end_RF_Depth_mm = 30/2; %This determines the maximum frame rate possible 
focalLength = 70;
track_WRT_First_Frame = 1;
timing_List_in_us = 0;
duration_of_Each_SubPulse_in_us = 200*5000000/transducer_Frequency_in_Hz;
gap_Between_Pulses_in_us = 10*5000000/transducer_Frequency_in_Hz; % Minimum value 10 us at 5 MHz
number_Of_Cycles_Per_SubPulse = round(duration_of_Each_SubPulse_in_us*((transducer_Frequency_in_Hz*10^-6)*2)/64);
duration_of_Each_SubPulse_in_us = (number_Of_Cycles_Per_SubPulse*64)/((transducer_Frequency_in_Hz*10^-6)*2);

total_Time_Length_of_Cardiac_Push_us = 1000;
evalin('base', ['number_Subpulses_in_Cardiac_Push =', num2str(round(total_Time_Length_of_Cardiac_Push_us/duration_of_Each_SubPulse_in_us))]);
evalin('base', ['number_Of_Cycles_Per_SubPulse =', num2str(number_Of_Cycles_Per_SubPulse)]);
evalin('base', ['gap_Between_Pulses_in_us = ', num2str(gap_Between_Pulses_in_us)]);

tube_Diameter = 19; %In wavelengths

evalin('base', 'number_Of_Angles = 1');
evalin('base', ['transducer_Frequency_in_Hz =', num2str(transducer_Frequency_in_Hz)]);
evalin('base', ['num_of_Pulses_per_Push = ', num2str(num_of_Pulses_per_Push)]);
evalin('base',['RF_Points_Per_Wavelength = ', num2str(points_Per_Wavelength)]);
evalin('base', ['IQ_Points_Per_Wavelength = ', num2str(points_Per_Wavelength_in_Image)]);
evalin('base', ['num_of_Frames_Per_Push_Cycle =', num2str(num_of_Frames_Per_Push_Cycle)]);
evalin('base', 'Resource.Parameters.numTransmit = 128;');  % number of transmit channels.
evalin('base', 'Resource.Parameters.numRcvChannels = 128;');  % number of receive channels.
evalin('base', ['Resource.Parameters.speedOfSound =', num2str(speed_Of_Sound)]);
evalin('base', 'Resource.Parameters.simulateMode = 1;');  % Run in simulation mode
evalin('base', 'Trans.name = ''L7-4''; Trans.frequency = transducer_Frequency_in_Hz/1000000;  Trans.units = ''wavelengths''; Trans = computeTrans(Trans); wavelength_in_mm = 1000*Resource.Parameters.speedOfSound/transducer_Frequency_in_Hz; Trans.maxHighVoltage = 100;');
evalin('base', ['focal_Length =', num2str(focalLength)]);
evalin('base', 'focal_X = 0;');
evalin('base', 'getReadytoFocus = 0;');
evalin('base', ['center_of_Vision = ', num2str(center_of_Vision_mm), '/wavelength_in_mm;']);
evalin('base', ['end_RF_Depth = ', num2str(end_RF_Depth_mm), '/wavelength_in_mm;']);
evalin('base','PData(1).sFormat = 1; PData(1).pdeltaX = 1/IQ_Points_Per_Wavelength; PData(1).pdeltaZ = 1/IQ_Points_Per_Wavelength; PData(1).Size(1,1) = 2*round((16/(wavelength_in_mm*PData(1).pdeltaZ))/2)+1; PData(1).Size(1,2) = 2*round((16/(wavelength_in_mm*PData(1).pdeltaX))/2)+1; PData(1).Size(1,3) = 1; PData(1).Origin = [-8/wavelength_in_mm,0,center_of_Vision - 8/wavelength_in_mm]; '); %PData(1).Size are all set to odd for perfect allignment on display

%Create parent window
screensize = get(0, 'Screensize');
mother_Window = figure('Visible','on','Position',screensize); %The Main window
set(mother_Window, 'MenuBar', 'none');
set(mother_Window, 'WindowButtonDownFcn', @actOnMouseClicks);
set(mother_Window, 'WindowButtonMotionFcn', @actOnMouseMove);
set(mother_Window,'CloseRequestFcn',@closeReqFunc);

current_File_Path = '';
%Operation Mode drop down
operation_Mode = uicontrol(mother_Window,'Style', 'popupmenu','Units','normalized', 'Position', [0.32 0.98 0.15 0.02], 'String', strvcat('Simulation Mode','File Mode','Data Acqisition Mode'), 'Value', 1,  'Callback', @operationMode_Callback);

axes_X_Size = 0.20;
axes_Y_Size = axes_X_Size*screensize(3)/screensize(4);
%Create Image axes
image_Frame_Axes_Handle = axes('Units','normalized','Position',[0.05,0.57,axes_X_Size,axes_Y_Size]);
xlabel(image_Frame_Axes_Handle, 'Width in Wavelengths');
ylabel(image_Frame_Axes_Handle, 'Depth in Wavelengths');

%Azes to display K Curve and time-Displacement Curves
shift_Display_Axes = axes('Units','normalized','Position',[0.3,0.57,axes_X_Size,axes_Y_Size]);
xlabel(shift_Display_Axes, 'Frequency');
ylabel(shift_Display_Axes, 'Amplitude');

%Create zoomed Image axes
image_Zoom_Frame_Axes_Handle = axes('Units','normalized','Position',[0.05,0.14,axes_X_Size,axes_Y_Size]);
xlabel(image_Zoom_Frame_Axes_Handle, 'Width in Wavelengths');
ylabel(image_Zoom_Frame_Axes_Handle, 'Depth in Wavelengths');

%Create zoomed middle RF axes
analysis_Axes_Handle = axes('Units','normalized','Position',[0.3,0.14,axes_X_Size,axes_Y_Size]);
xlabel(analysis_Axes_Handle, 'Depth in Wavelengths');
ylabel(analysis_Axes_Handle, 'Amplitude');

assignin('base', 'user_Fig_Handle', image_Frame_Axes_Handle);
assignin('base', 'zoomed_Fig_Handle', image_Zoom_Frame_Axes_Handle);
        
%Create frame slider
frame_Num = 1;
frame_Slider_Label = uicontrol(mother_Window, 'Style', 'text','String','Frame Number = 1','Units','normalized', 'Position', [0.3 0.01+0.02 0.3 0.02]);
frame_Slider = uicontrol(mother_Window, 'Style', 'slider', 'Min',1,'Max',num_of_Frames_Per_Push_Cycle,'Value',frame_Num,'Units','normalized', 'Position', [0.3 0.01 0.3 0.02]);
addlistener(frame_Slider,'ContinuousValueChange',@frame_Slider_Callback);

%Create zoom slider
zoom_Level = 20;
zoom_Slider_Label = uicontrol(mother_Window, 'Style', 'text','String',['Zoom Level = ', num2str(100/zoom_Level)],'Units','normalized', 'Position', [0.3 0.05+0.02 0.3 0.02]);
zoom_Slider = uicontrol(mother_Window, 'Style', 'slider', 'Min',5,'Max',40,'Value',zoom_Level,'Units','normalized', 'Position', [0.3 0.05 0.3 0.02]);
addlistener(zoom_Slider,'ContinuousValueChange',@zoom_Slider_Callback);

voltage_Levels = [50:-1:5];
current_Voltage_Index = 1;
voltageList = uicontrol(mother_Window,'Style', 'popupmenu','Units','normalized', 'Position', [0.86 0.97 0.06 0.02], 'String', num2str(voltage_Levels'), 'Value', current_Voltage_Index,  'Callback', @voltageChange_Callback);
voltageListLabel = uicontrol(mother_Window, 'Style', 'text','String','Voltage List','Units','normalized', 'Position', [0.86 0.988 0.06 0.01]);

pressure_Levels = [30:20:180];
current_Pressure_Index = 1;
pressureList = uicontrol(mother_Window,'Style', 'popupmenu','Units','normalized', 'Position', [0.93 0.97 0.06 0.02], 'String', num2str(pressure_Levels'), 'Value', current_Pressure_Index,  'Callback', @pressureChange_Callback);
pressureListLabel = uicontrol(mother_Window, 'Style', 'text','String','Pressure List','Units','normalized', 'Position', [0.93 0.988 0.06 0.01]);

time_List = [1:20];
current_Time_Index = 1;
timeList = uicontrol(mother_Window,'Style', 'popupmenu','Units','normalized', 'Position', [0.79 0.97 0.06 0.02], 'String', num2str(time_List'), 'Value', current_Pressure_Index,  'Callback', @timeChange_Callback);
timeListLabel = uicontrol(mother_Window, 'Style', 'text','String','Time List','Units','normalized', 'Position', [0.79 0.988 0.06 0.01]);

%Use Specified Pressure List
pressure_List_Label = uicontrol(mother_Window, 'Style', 'text','String','Enter pressure range here','Units','normalized', 'Position', [0.82 0.92 0.15 0.02]);
pressure_List_Command = uicontrol(mother_Window, 'Style', 'edit','String','30:30:120','Units','normalized', 'Position', [0.82 0.89 0.15 0.02]);
pressure_Levels = [30:20:180];

%Radio Button Group to Select Parameter
bg2 = uibuttongroup(mother_Window,'Visible','on',...
                  'Position',[0.82 0.845 0.15 0.04],...
                  'Title', 'Sweep Parameter');
              
% Create two radio buttons in the button group.
enable_Time_Sweep = uicontrol(bg2,'Style',...
                  'radiobutton',...
                  'String','Time Sweep',...
                  'Units','normalized', 'Position',[0.2 0.30 0.6 0.5],...
                  'HandleVisibility','off');
              
enable_Voltage_Sweep = uicontrol(bg2,'Style','radiobutton',...
                  'String','Voltage Sweep',...
                  'Units','normalized', 'Position',[0.5 0.30 0.4 0.5],...
                  'HandleVisibility','off');
              
%User Specified Voltage List
voltage_List_Label = uicontrol(mother_Window, 'Style', 'text','String','Enter voltage range here','Units','normalized', 'Position', [0.82 0.81 0.07 0.018]);
voltage_List_Command = uicontrol(mother_Window, 'Style', 'edit','String','50:-1:5','Units','normalized', 'Position', [0.90 0.81 0.07 0.02]);

%User Specified Time List
time_List_Label = uicontrol(mother_Window, 'Style', 'text','String',['Enter time range in (No. of ', num2str(duration_of_Each_SubPulse_in_us+gap_Between_Pulses_in_us),' us pulses)'],'Units','normalized', 'Position', [0.82 0.78 0.07 0.025]);
time_List_Command = uicontrol(mother_Window, 'Style', 'edit','String','1:20','Units','normalized', 'Position', [0.90 0.78 0.07 0.02]);

num_Of_Frames_Per_Voltage_Label = uicontrol(mother_Window, 'Style', 'text','String','Enter number of frames per voltage here','Units','normalized', 'Position', [0.82 0.75 0.15 0.02]);
num_Of_Frames_Per_Voltage = uicontrol(mother_Window, 'Style', 'edit','String','3','Units','normalized', 'Position', [0.82 0.72 0.15 0.02]);

%Setting for number of push pulses
trans_Freq_Label = uicontrol(mother_Window,'Style', 'text','Units','normalized', 'Position', [0.001 0.98 0.05 0.015], 'String', 'Transducer Freq.');
trans_Freq_Text = uicontrol(mother_Window,'Style', 'edit','Units','normalized', 'Position', [0.001 0.965 0.045 0.015], 'String',  num2str(transducer_Frequency_in_Hz), 'Callback', @set_Trans_Freq);

set_Speed_of_Sound_Label = uicontrol(mother_Window,'Style', 'text','Units','normalized', 'Position', [0.001 0.95 0.05 0.015], 'String', 'Speed of Sound');
set_Speed_of_Sound_Text = uicontrol(mother_Window,'Style', 'edit','Units','normalized', 'Position', [0.001 0.935 0.045 0.015], 'String', num2str(speed_Of_Sound), 'Callback', @set_Speed_of_Sound);

%Show live images
show_Live_Images = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.05 0.98 0.15 0.02], 'String', 'Show Live Images', 'value', 0, 'Callback', @show_Live_Images_Callback);
show_Ref_Frames = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.12 0.98 0.1 0.02], 'String', 'Show Reference Frames', 'value', 0, 'Callback', @show_Ref_Frames_Callback);

push_On_During_View = 0;
evalin('base', ['push_On_During_View = ', num2str(push_On_During_View)]) 
push_On_Check = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.05 0.96 0.15 0.02], 'String', 'Push pulse on', 'value', push_On_During_View, 'Callback', @push_On_Check_Callback);

push_Viewer_Voltage = 50;
evalin('base',['push_Viewer_Voltage = ', num2str(push_Viewer_Voltage)]);
push_Viewer_Voltage_Slider_Label = uicontrol(mother_Window, 'Style', 'text','String',['Push voltage during view =' num2str(push_Viewer_Voltage), ' V'],'Units','normalized', 'Position', [0.11 0.96 0.12 0.02]);
push_Viewer_Voltage_Slider = uicontrol(mother_Window, 'Style', 'slider', 'Min',5,'Max',100,'Value',push_Viewer_Voltage,'Units','normalized', 'Position', [0.05 0.95-0.01 0.15 0.01]);
addlistener(push_Viewer_Voltage_Slider,'ContinuousValueChange',@push_Viewer_Voltage_Slider_Callback);
evalin('base', 'switch_Between_Ref_Tracking =0');

time_Between_Acq_in_Viewer_Mode_Label = uicontrol(mother_Window, 'Style', 'text','String','Duration between acquisitions (ms)','Units','normalized', 'Position', [0.22 0.98 0.1 0.02]);
time_Between_Acq_in_Viewer_Mode_Text = uicontrol(mother_Window, 'Style', 'edit','String','10','Units','normalized', 'Position', [0.22 0.96 0.1 0.02]);
evalin('base', 'time_Between_Acq_in_Viewer_Mode_Text =0');
assignin('base', 'time_Between_Acq_in_Viewer_Mode_Text',  str2double(get(time_Between_Acq_in_Viewer_Mode_Text,'string')));

%Acquire Data Button
acquire_Data_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.82 0.67 0.15 0.03], 'String', 'Acquire Data', 'Callback', @acquire_Data_Callback);
save_Data_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.82 0.638 0.15 0.025], 'String', 'Save Data', 'Callback', @save_Data_Callback);

%Hydrophone Measurements Interface
elevational_Focus_Measurement_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.82 0.2 0.15 0.025], 'String', 'Start Beam Profile Test', 'Callback', @elevational_Focus_Mmt_Callback);
focussed_Beam_for_Elevational_Test_Check = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.82 0.23 0.15 0.025], 'String', 'Use focussed beam', 'value', 0);

PWV_Data_Acq_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.82 0.15 0.07 0.025], 'String', 'Acquire PWV Data', 'Callback', @PWV_Data_Acq_Callback);
Save_PWV_Data_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.90 0.15 0.07 0.025], 'String', 'Save PWV Data', 'Callback', @save_PWV_Data_Callback);
Load_PWV_Data_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.82 0.12 0.07 0.025], 'String', 'Load PWV Data', 'Callback', @load_PWV_Data_Callback);
Analyze_PWV_Data_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.90 0.12 0.07 0.025], 'String', 'Analyze PWV Data', 'Callback', @analyze_PWV_Data_Callback);

%Radio Button Group to Select Parameter
bg = uibuttongroup(mother_Window,'Visible','on',...
                  'Position',[0.3 0.90 0.1 0.04],...
                  'Title', 'Plot Type', ...
                  'SelectionChangeFcn', @displacement_Parameter_View_Changed);
              
% Create three radio buttons in the button group.
recovery_Plot_But = uicontrol(bg,'Style',...
                  'radiobutton',...
                  'String','Recovery Plot',...
                  'Units','normalized', 'Position',[0 0.30 0.6 0.5],...
                  'HandleVisibility','off');
              
K_Plot_But = uicontrol(bg,'Style','radiobutton',...
                  'String','K Plot',...
                  'Units','normalized', 'Position',[0.6 0.30 0.4 0.5],...
                  'HandleVisibility','off');
K_Plot_Tracking_Frame_Num =2;

              %Radio Button Group to Select Parameter
bg1 = uibuttongroup(mother_Window,'Visible','on',...
                  'Position',[0.4 0.90 0.1 0.04],...
                  'Title', 'Tracking Mode', ...
                  'SelectionChangeFcn', @displacement_Parameter_View_Changed);
              
% Create three radio buttons in the button group.     
track_Mode_1D = uicontrol(bg1,'Style','radiobutton',...
                  'String','1D Tracking',...
                  'Units','normalized', 'Position',[0 0.30 0.5 0.5],...
                  'HandleVisibility','off');
              
track_Mode_2D = uicontrol(bg1,'Style','radiobutton',...
                  'String','2D Tracking',...
                  'Units','normalized', 'Position',[0.5 0.30 0.5 0.5],...
                  'HandleVisibility','off');

              
%Cariac cycle control group
bg3 = uibuttongroup(mother_Window,'Visible','on',...
                  'Position',[0.82 0.400 0.15 0.2],...
                  'Title', 'Cardiac Cycle Acqisition');

pings_Per_Second_Label = uicontrol(bg3,'Style', 'text', 'String', 'Pings per Second', ...
    'Units','normalized', 'Position', [0.01 0.82 0.5 0.12]);
pings_Per_Second_Text = uicontrol(bg3,'Style', 'edit', 'String', '30', ...
    'Units','normalized', 'Position', [0.5 0.85 0.4 0.12]);
cardiac_Probe_Voltage_Label = uicontrol(bg3,'Style', 'text', 'String', 'Push Voltage (V)', ...
    'Units','normalized', 'Position', [0.01 0.62 0.5 0.12]);
cardiac_Probe_Voltage_Text = uicontrol(bg3,'Style', 'edit', 'String', '50', ...
    'Units','normalized', 'Position', [0.5 0.65 0.4 0.12]);
duration_Of_Cardiac_Acq_Label = uicontrol(bg3,'Style', 'text', 'String', 'Acquisition Duration (ms)', ...
    'Units','normalized', 'Position', [0.01 0.42 0.5 0.12]);
duration_Of_Cardiac_Acq_Text = uicontrol(bg3,'Style', 'edit', 'String', '1000', ...
    'Units','normalized', 'Position', [0.5 0.45 0.4 0.12]);
no_of_Frames_Per_Cardiac_Push_Label = uicontrol(bg3,'Style', 'text', 'String', 'No. of Frames per Push', ...
    'Units','normalized', 'Position', [0.01 0.22 0.5 0.12]);
no_of_Frames_Per_Cardiac_Push_Text = uicontrol(bg3,'Style', 'edit', 'String', '60', ...
    'Units','normalized', 'Position', [0.5 0.25 0.4 0.12]);
acquire_Cardiac_Cycle_But = uicontrol(bg3,'Style', 'pushbutton', 'String', 'Acquire Cardiac Cycle', ...
    'Units','normalized', 'Position', [0.01 0.12 0.45 0.12], 'Callback', @acquire_Cardiac_Cycle_Callback);
save_Cardiac_Cycle_But = uicontrol(bg3,'Style', 'pushbutton', 'String', 'Save Cardiac Cycle', ...
    'Units','normalized', 'Position', [0.51 0.12 0.45 0.12], 'Callback', @save_Cardiac_Cycle_Callback);
save_Cardiac_Cycle_Analysis_But = uicontrol(bg3,'Style', 'pushbutton', 'String', 'Save Analysis Data', ...
    'Units','normalized', 'Position', [0.25 0.01 0.45 0.10], 'Callback', @save_Cardiac_Cycle_Analysis_Callback);

cardiac_Cycle_Mode =0;
PWV_Measurement_Mode =0;

current_Image_Frame = [];
first_Image_Frame = [];
track_Button = uicontrol(mother_Window, 'Style', 'pushbutton', 'String', 'Track', 'Units','normalized', 'Position', [0.57 0.94 0.05 0.06], 'Callback', @track_Button_Callback);
track_Stop = 1;

% flash_Angles_Check = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.47 0.98 0.1 0.02], 'String', 'Enable Flash Angles', 'value', 0, 'Callback', @enable_Flash_Angles_Callback);
track_Both_Sides_Check = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.47 0.96 0.1 0.02], 'String', 'Track both sides', 'value', 0);
display_Images_Check = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.47 0.98 0.1 0.02], 'String', 'Switch off Image Display', 'value', 0);
track_at_Focus_Check = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.47 0.94 0.1 0.02], 'String', 'Track at Focus', 'value', 1);

evalin('base', 'TGC_On = 0;');
TGC_On_Check = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.001 0.918 0.045 0.015], 'String', 'TGC On', 'value', 0,'Callback', @TGC_On_Callback);

%Freq Analysis and Saving Data
freq_Analysis_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.52 0.45 0.07 0.025], 'String', 'Analyze Frequency', 'Callback', @analyze_Freq_Callback);
fft_Start_Index_Label = uicontrol(mother_Window, 'Style', 'Text','String','FFT Start Index','Units','normalized', 'Position', [0.63 0.47 0.07 0.025]);
fft_Start_Index_Text = uicontrol(mother_Window, 'Style', 'edit','String','2','Units','normalized', 'Position', [0.63 0.45 0.07 0.025]);
merge_Same_Pressures_Check_Box = uicontrol(mother_Window,'Style', 'checkbox','Units','normalized', 'Position', [0.52 0.48 0.1 0.025], 'String', 'Merge same pressure data');

track_Diameter_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.52 0.42 0.1 0.025], 'String', 'Track Diameter', 'Callback', @track_Vertical_Diameter_Callback);
tube_Density_Text = uicontrol(mother_Window, 'Style', 'text','String','Wall Density (Kg/m^3)','Units','normalized', 'Position', [0.52 0.382 0.08 0.02]);
tube_Density_Value = uicontrol(mother_Window, 'Style', 'edit','String','1000','Units','normalized', 'Position', [0.6 0.38 0.05 0.025]);

D0_Text = uicontrol(mother_Window, 'Style', 'text','String','Relaxed Diameter (mm)','Units','normalized', 'Position', [0.52 0.352 0.08 0.02]);
D0_Value = uicontrol(mother_Window, 'Style', 'edit','String','5.0','Units','normalized', 'Position', [0.6 0.35 0.05 0.025]);

Pd_Text = uicontrol(mother_Window, 'Style', 'edit','String','Pd (mmHg)','Units','normalized', 'Position', [0.52 0.32 0.04 0.025]);
Ps_Text = uicontrol(mother_Window, 'Style', 'edit','String','Ps (mmHg)','Units','normalized', 'Position', [0.56 0.32 0.04 0.025]);
calibrate_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.60 0.32 0.05 0.025], 'String', 'Calibrate', 'Callback', @calibration_Callback);
pressure_Calculation_Button = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.52 0.28 0.06 0.025], 'String', 'Calculate Pressures', 'Callback', @pressure_Calculation_Callback);
save_Analysis_Data = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.59 0.28 0.06 0.025], 'String', 'Save Analysis Data', 'Callback', @save_Analysis_Callback);

Image_Rect_Coordinates = [0 0 1 1];
Image_Rect_Coordinates_Back_Wall = [0 0 1 1];
wall_Selection_Counter =2;
RF_Shift_Arr = [];
maxCorr_Arr = [];
recovery_Arr = [];

diameter_Array = [];
thickness_Array =[];
freq_Peaks = [];
calculated_Pressures = [];

full_Image_Frames_Movie = struct('cdata',[],'colormap',[]);
zoomed_Image_Frames_Movie = struct('cdata',[],'colormap',[]);
current_Measured_Pressure =0;
pressure_Indicator = uicontrol(mother_Window,'Style', 'text','Units','normalized', 'Position', [0.82 0.3 0.15 0.04], 'String', strvcat('Current Pressure','0.0 mmHg'),'FontSize', 12,'ForegroundColor',[1 0 0], 'FontWeight','bold');

function test_Pressure_Transducer_Speed()
    %Call this function to verify spped streaming of pressure data
    pressure_Reader(1);
    immediate_Data= zeros(5000,1);
    figure
    while(1)
    for i=1:5000
        immediate_Data(i) = 51.7*typecast(uint8(pressure_Reader(3)),'single');
    end
    plot(immediate_Data);
    %ylim([50 120]);
    drawnow
    end
end

% test_Pressure_Transducer_Speed()

pressure_Data_Refresh_Timer = timer;
pressure_Data_Refresh_Timer.StartFcn = @timer_Start_Event;
pressure_Data_Refresh_Timer.TimerFcn = @timer_Tick_Event;
pressure_Data_Refresh_Timer.StopFcn = @timer_Stop_Event;
pressure_Data_Refresh_Timer.Period = 0.5;
pressure_Data_Refresh_Timer.TasksToExecute = Inf;
pressure_Data_Refresh_Timer.ExecutionMode = 'fixedRate';
start(pressure_Data_Refresh_Timer);

function closeReqFunc(hObject,event)
    try
        stop(pressure_Data_Refresh_Timer);
    catch
        pressure_Reader(2);
    end
    delete(hObject);
end 

function timer_Start_Event(varargin)
    pressure_Reader(1);
end

function timer_Tick_Event(varargin)
    current_Measured_Pressure= 51.7*typecast(uint8(pressure_Reader(3)),'single');
    set(pressure_Indicator,'String', strvcat('Current Pressure', [num2str(current_Measured_Pressure),' mmHg']));
end

function timer_Stop_Event(varargin)
    pressure_Reader(2);
end

function track_Button_Callback(varargin)
    if(track_Stop ==0) 
        track_Stop = 1; 
        set(track_Button, 'String', 'Track'); 
        return;
    else
        track_Stop =0; 
        set(track_Button, 'String', 'Stop tracking'); 
    end
    K_Plot_Tracking_Frame_Num =0;
    
    if(cardiac_Cycle_Mode ==0)
    if(measurement.sweepMode ==1)
        sweep_Variable = voltage_Levels;
    else
        sweep_Variable = time_List;
    end
    RF_Shift_Arr = zeros(num_of_Frames_Per_Push_Cycle-1,length(sweep_Variable),length(pressure_Levels));
    maxCorr_Arr = zeros(num_of_Frames_Per_Push_Cycle-1,length(sweep_Variable),length(pressure_Levels));
    full_Image_Frames_Movie = struct('cdata',[],'colormap',[]);
    zoomed_Image_Frames_Movie = struct('cdata',[],'colormap',[]);
    for k = 1:length(pressure_Levels)
        set(pressureList,'Value', k);
        pressureChange_Callback();
        for j = 1:length(sweep_Variable)
            if(measurement.sweepMode ==1)
                set(voltageList,'Value', j);
                voltageChange_Callback();
            else
                set(timeList,'Value', j);
                timeChange_Callback();
            end
            i_Range = 3:num_of_Frames_Per_Push_Cycle;
            for i = 1:length(i_Range)
                frame_Num = i_Range(i);
                current_Image_Frame = getImageFrame(k, frame_Num,j);
                replot_Everything();
                movie_Size = 360;
                zoomed_Image_Frames_Movie((k-1)*length(sweep_Variable)*length(i_Range)+(j-1)*length(i_Range)+i) = getframe(image_Zoom_Frame_Axes_Handle);
                zoomed_Image_Frames_Movie((k-1)*length(sweep_Variable)*length(i_Range)+(j-1)*length(i_Range)+i).cdata = zoomed_Image_Frames_Movie((k-1)*length(sweep_Variable)*length(i_Range)+(j-1)*length(i_Range)+i).cdata(1:movie_Size,1:movie_Size,:);
                full_Image_Frames_Movie((k-1)*length(sweep_Variable)*length(i_Range)+(j-1)*length(i_Range)+i) = getframe(image_Frame_Axes_Handle);
                full_Image_Frames_Movie((k-1)*length(sweep_Variable)*length(i_Range)+(j-1)*length(i_Range)+i).cdata = full_Image_Frames_Movie((k-1)*length(sweep_Variable)*length(i_Range)+(j-1)*length(i_Range)+i).cdata(1:movie_Size,1:movie_Size,:);
                if(track_Stop == 1)
                    return;
                end
            end
        end
    end
    measurement.RF_Shift_Arr = RF_Shift_Arr;
    track_Stop = 1;
    set(track_Button, 'String', 'Track')
    beep; beep; beep;
    myVideo = VideoWriter('zoomed_Image_Frames.avi');
    open(myVideo);
    writeVideo(myVideo, zoomed_Image_Frames_Movie);
    close(myVideo);
    myVideo = VideoWriter('full_Image_Frames.avi');
    open(myVideo);
    writeVideo(myVideo, full_Image_Frames_Movie);
    close(myVideo);
    else
        first_Image_Frame = getImageFrame_For_Cardiac_Cycle_Data(1);
        tube_Diameter = find_Tube_Diameter(0);
        current_Dia_Change = 0;
        i_Range = 1:cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push*cardiac_Cycle_Measurement.total_No_of_Pings;
        RF_Shift_Arr = zeros(1,1,1);
        for i = 1:length(i_Range)
            frame_Num = i_Range(i);
            current_Image_Frame = getImageFrame_For_Cardiac_Cycle_Data(frame_Num);
            if(mod(i-1, cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push) ==0)
                first_Image_Frame = getImageFrame_For_Cardiac_Cycle_Data(1);
                replotForCardiacCycle(0);
                current_Dia_Change = RF_Shift_Arr(frame_Num,1, 1);
                first_Image_Frame = getImageFrame_For_Cardiac_Cycle_Data(i);
            else
                replotForCardiacCycle(current_Dia_Change);
            end
            
            if(track_Stop == 1)
                return;
            end
         end
    end
    track_Stop = 1; 
    set(track_Button, 'String', 'Track'); 
end

function frame_Slider_Callback(varargin)
    frame_Num = floor(get(frame_Slider,'Value'));
    set(frame_Slider_Label,'String',['Frame Number = ', num2str(frame_Num)]);
    if(cardiac_Cycle_Mode ==0)
        current_Image_Frame = getImageFrame(current_Pressure_Index,frame_Num,current_Voltage_Index*current_Time_Index);
        replot_Everything();
    else
        current_Image_Frame = getImageFrame_For_Cardiac_Cycle_Data(frame_Num);
        replotForCardiacCycle(0)
    end
end

function zoom_Slider_Callback(varargin)
    zoom_Level = get(zoom_Slider,'Value');
    set(zoom_Slider_Label,'String',['Zoom Level = ', num2str(100/zoom_Level)]);
    replot_Everything();
end

function [fullRFFrame] = getRCVFullRFFrame(pressure_Index, frame_Num, voltage_Index)
        points_Per_Wavelength = measurement.points_Per_IQ_Wavelength;
        fullRFFrame = IQtoRF(measurement.seqData(pressure_Index).IQData(:,:,frame_Num+((voltage_Index-1)*num_of_Frames_Per_Push_Cycle)));
%         fullRFFrame = real(measurement.seqData(pressure_Index).IQData(:,:,frame_Num+((voltage_Index-1)*num_of_Frames_Per_Push_Cycle)));
end

function [RF_Arr] = IQtoRF(IQ_Arr)
    IQ_Arr(2:2:end,:) = -IQ_Arr(2:2:end,:);
    real_Arr = real(IQ_Arr);
    imag_Arr = imag(IQ_Arr);
    S = size(real_Arr);
    RF_Arr = zeros(S(1)*2,S(2));

    for i = 1:S(2)
        IR = interp(real_Arr(:,i),2);
        II = interp(imag_Arr(:,i),2);
        
        RF_Arr((1:4:2*S(1)),i) = IR(1:4:2*S(1));
        RF_Arr((2:4:2*S(1)),i) = II(2:4:2*S(1));
        RF_Arr((3:4:2*S(1)),i) = -IR(3:4:2*S(1));
        RF_Arr((4:4:2*S(1)),i) = -II(4:4:2*S(1));
    end
end


function [imageFrame] = getImageFrame(pressure_Index, frame_Num, voltage_Index)
    imageFrame = measurement.seqData(pressure_Index).imageData(:,:,frame_Num+((voltage_Index-1)*num_of_Frames_Per_Push_Cycle));
end

function [imageFrame] = getImageFrame_For_Cardiac_Cycle_Data(frame_Num)
    imageFrame = cardiac_Cycle_Measurement.imageData(:,:,frame_Num);
end

function actOnMouseClicks(varargin)
    cursorPoint = get(image_Frame_Axes_Handle, 'CurrentPoint');
    curX = cursorPoint(1,1);
    curY = cursorPoint(1,2);
    xLimits = get(image_Frame_Axes_Handle, 'xlim');
    yLimits = get(image_Frame_Axes_Handle, 'ylim');
    if (~(curX > min(xLimits) && curX < max(xLimits) && curY > min(yLimits) && curY < max(yLimits)))
        return;
    end
    
    if(focalLength ==0 || elevational_Test_Running ==1)
        focalLength = curY;
        evalin('base', ['focal_Length =', num2str(focalLength)]);
        evalin('base', ['focal_X =', num2str(curX)]);
        evalin('base','save_Snapshot = 1');
        return
    else
        focalLength = curY;
        evalin('base', ['focal_Length =', num2str(focalLength)]);
        evalin('base', ['focal_X =', num2str(curX)]);
        if(cardiac_Cycle_Mode ==1)
            try
                evalin('base','TX(push_TX_Num).waveform = 2;');
                evalin('base','TX(push_TX_Num).Origin = [focal_X, 0, 0];')
                evalin('base','central_Element = find(Trans.ElementPos >= focal_X, 1, ''first'');')
                evalin('base','TX(push_TX_Num).focus = focal_Length;');
                evalin('base','TX(push_TX_Num).Apod =  zeros(1,Trans.numelements);');
                evalin('base','TX(push_TX_Num).Apod(central_Element-32:central_Element+32) = 1;')
                evalin('base','TX(push_TX_Num).Steer = [0 0];');
                evalin('base','TX(push_TX_Num).Delay = computeTXDelays(TX(push_TX_Num));');
                Control = evalin('base','Control');
                Control.Command = 'update&Run';
                Control.Parameters = {'TX'};
                assignin('base','Control', Control);
            catch
                disp('couldn''t assign control variable');
            end
        end
    end
    
    if(cardiac_Cycle_Mode ==0)
        first_Image_Frame = getImageFrame(current_Pressure_Index, 1, current_Voltage_Index*current_Time_Index);
    else
        first_Image_Frame = getImageFrame_For_Cardiac_Cycle_Data(1);
    end
    
    if (curX > min(xLimits) && curX < max(xLimits) && curY > min(yLimits) && curY < max(yLimits))
        if(get(track_at_Focus_Check,'value') ==0 && wall_Selection_Counter ==1)
            Image_Rect_Coordinates = find_Rect(current_Image_Frame, image_Frame_Axes_Handle, curX, curY, zoom_Level);
            wall_Selection_Counter =2;
        elseif(get(track_at_Focus_Check,'value') ==0 && wall_Selection_Counter ==2)
            Image_Rect_Coordinates_Back_Wall = find_Rect(current_Image_Frame, image_Frame_Axes_Handle, curX, curY, zoom_Level);
            wall_Selection_Counter =1;
        else
            Image_Rect_Coordinates = find_Rect(current_Image_Frame, image_Frame_Axes_Handle, curX, curY, zoom_Level);
        end
        if(cardiac_Cycle_Mode ==0)
            replot_Everything();
        else
            replotForCardiacCycle(-100);
        end
    end
end

function [rect] = find_Rect(target_Frame, target_Axes, curX, curY, zoom_Level)
    axes(target_Axes)
    if(cardiac_Cycle_Mode ==0)
        pData = measurement.PData;
    else
        pData = cardiac_Cycle_Measurement.PData;
    end
    Origin = pData.Origin;
    S = size(target_Frame);
    X_Int = pData.pdeltaX;
    Z_Int = pData.pdeltaZ;
    if(target_Axes == image_Frame_Axes_Handle)
        imagesc(Origin(1)+ [0:S(2)-1]*X_Int, Origin(3)+[0:S(1)-1]*Z_Int, non_Linear_Gain_On_Image(target_Frame));
    else
        imagesc(Origin(1)+ [0:S(2)-1]*X_Int, Origin(3)+([0:S(1)-1]*Z_Int)/2, target_Frame);
    end
    
    half_Zoom_Len = fliplr((size(target_Frame).*[pData(1).pdeltaZ, pData(1).pdeltaX])/zoom_Level);
    
    xLimits = get(target_Axes, 'xlim');
    yLimits = get(target_Axes, 'ylim');
    rect.x1 = max(curX-half_Zoom_Len(1),min(xLimits));
    rect.x2 = min(curX+half_Zoom_Len(1),max(xLimits));
    if(target_Axes == image_Frame_Axes_Handle)
        rect.y1 = max(curY-half_Zoom_Len(2),min(yLimits));
        rect.y2 = min(curY+half_Zoom_Len(2),max(yLimits));
    else
        rect.y1 = max(curY-half_Zoom_Len(2)/2,min(yLimits));
        rect.y2 = min(curY+half_Zoom_Len(2)/2,max(yLimits));
    end
end

function replot_Everything()
    display_Off = get(display_Images_Check, 'value');
    pData = measurement.PData;
    Origin = pData.Origin;
    S = size(current_Image_Frame);
    X_Int = pData.pdeltaX;
    Z_Int = pData.pdeltaZ;
    zoom_Interval = 1/100; %500 points per wavelength
    rect_Z_Shift = tube_Diameter;
    rect_X_Shift = 0;
    
    if(display_Off==0)
    axes(image_Frame_Axes_Handle);
    cla;
    imagesc(Origin(1)+ [0:S(2)-1]*X_Int, Origin(3)+[0:S(1)-1]*Z_Int,  non_Linear_Gain_On_Image(current_Image_Frame));
    xlim([Origin(1) Origin(1)+ (S(2)-1)*X_Int]);
    ylim([Origin(3) Origin(3)+(S(1)-1)*Z_Int]);
    hold on;
    scatter(measurement.seqData(current_Pressure_Index).fociix, measurement.seqData(current_Pressure_Index).focii, 100, '+', 'MarkerEdgeColor',[0.7 0.7 0], 'MarkerFaceColor',[0 0 0.7], 'LineWidth',2);
    rectangle('Position', [Image_Rect_Coordinates.x1 Image_Rect_Coordinates.y1 Image_Rect_Coordinates.x2-Image_Rect_Coordinates.x1 Image_Rect_Coordinates.y2-Image_Rect_Coordinates.y1])
    W = Image_Rect_Coordinates.x2-Image_Rect_Coordinates.x1;
    line([Image_Rect_Coordinates.x1+W/2, Image_Rect_Coordinates.x1+W/2], [Image_Rect_Coordinates.y1 Image_Rect_Coordinates.y2]);
    if(get(track_Both_Sides_Check, 'Value') ==1)
        if(get(track_at_Focus_Check,'value') ==1)
            rectangle('Position', [Image_Rect_Coordinates.x1+rect_X_Shift Image_Rect_Coordinates.y1+rect_Z_Shift Image_Rect_Coordinates.x2-Image_Rect_Coordinates.x1 Image_Rect_Coordinates.y2-Image_Rect_Coordinates.y1]);
            line([Image_Rect_Coordinates.x1+W/2, Image_Rect_Coordinates.x1+W/2]+rect_X_Shift, [Image_Rect_Coordinates.y1 Image_Rect_Coordinates.y2]+rect_Z_Shift);
        else
            rectangle('Position', [Image_Rect_Coordinates_Back_Wall.x1 Image_Rect_Coordinates_Back_Wall.y1 Image_Rect_Coordinates_Back_Wall.x2-Image_Rect_Coordinates_Back_Wall.x1 Image_Rect_Coordinates_Back_Wall.y2-Image_Rect_Coordinates_Back_Wall.y1]);
            line([Image_Rect_Coordinates_Back_Wall.x1+W/2, Image_Rect_Coordinates_Back_Wall.x1+W/2]+rect_X_Shift, [Image_Rect_Coordinates_Back_Wall.y1 Image_Rect_Coordinates_Back_Wall.y2]+rect_Z_Shift);
        end
    end
    text(min(xlim)+diff(xlim)/10,max(ylim)-diff(ylim)/10, strvcat(['Pressure = ', num2str(measurement.seqData(get(pressureList, 'value')).P),' mmHg'],...
        ['Voltage = ',num2str(measurement.seqData(get(pressureList, 'value')).V(get(voltageList, 'value'))),' V'],...
        ['Pulse Duration = ',num2str(measurement.seqData(get(pressureList, 'value')).T(get(timeList, 'value'))),'\mus'],...
        ['Frame number =', num2str(frame_Num)]), 'Color','white','FontSize',10);
    end
    
    Z_SubAxis = round(Image_Rect_Coordinates.y1/Z_Int):round(Image_Rect_Coordinates.y2/Z_Int);
    X_SubAxis = round(Image_Rect_Coordinates.x1/X_Int):round(Image_Rect_Coordinates.x2/X_Int);
    zoomed_Curr_Image = current_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int)); %The ROI section of current image
    zoomed_First_Image = first_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int));  %The ROI section of first image
    
    xShiftF = 0;
    yShiftF = 0;
    xShiftB = 0;
    yShiftB = 0;
    
    if(get(track_Mode_2D, 'Value') == 1) %Track 2D sections
        start_Point = Z_SubAxis(1)*Z_Int;    
        end_Point = Z_SubAxis(end)*Z_Int; 
        Z_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);

        start_Point = X_SubAxis(1)*X_Int;
        end_Point = X_SubAxis(end)*X_Int;
        X_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);
        [X, Z] = meshgrid(X_SubAxis*X_Int, Z_SubAxis*Z_Int);
        [Xq, Zq] = meshgrid(X_SubAxis_Zoomed, Z_SubAxis_Zoomed);
        zoomed_Curr_Image = interp2(X, Z, zoomed_Curr_Image, Xq, Zq, 'spline');
        zoomed_First_Image = interp2(X, Z, zoomed_First_Image, Xq, Zq, 'spline');
        
        if(display_Off==0)
            axes(image_Zoom_Frame_Axes_Handle);
            cla reset;
            imagesc(X_SubAxis_Zoomed, Z_SubAxis_Zoomed, zoomed_Curr_Image);
            hold on;
            line([Image_Rect_Coordinates.x1+W/2, Image_Rect_Coordinates.x1+W/2], [Image_Rect_Coordinates.y1 Image_Rect_Coordinates.y2]);
            text(min(xlim)+diff(xlim)/10,max(ylim)-diff(ylim)/10, strvcat(['Pressure = ', num2str(measurement.seqData(get(pressureList, 'value')).P),' mmHg'],...
                ['Voltage = ',num2str(measurement.seqData(get(pressureList, 'value')).V(get(voltageList, 'value'))), ' V'],...
                ['Pulse Duration = ',num2str(measurement.seqData(get(pressureList, 'value')).T(get(timeList, 'value'))),' \mus'],...
                ['Frame number =', num2str(frame_Num)]), 'Color','white','FontSize',10);
        end

        X = xcorr2(zoomed_First_Image, zoomed_Curr_Image);
        CorrCenterX = length(X_SubAxis_Zoomed);
        CorrCenterY = length(Z_SubAxis_Zoomed);

        [max_Corr idx] = max(X(:));
        [shiftY shiftX] = ind2sub(size(X),idx);
        xShiftF = -(shiftX - CorrCenterX)*zoom_Interval;
        yShiftF = (shiftY - CorrCenterY)*zoom_Interval;
        xShiftB = 0;
        yShiftB = 0;
        if(get(track_Both_Sides_Check, 'Value') ==1)
            if(get(track_at_Focus_Check,'value')==1)
                Z_SubAxis  = Z_SubAxis + rect_Z_Shift/Z_Int;
            else
                Z_SubAxis = round(Image_Rect_Coordinates_Back_Wall.y1/Z_Int):round(Image_Rect_Coordinates_Back_Wall.y2/Z_Int);
                X_SubAxis = round(Image_Rect_Coordinates_Back_Wall.x1/X_Int):round(Image_Rect_Coordinates_Back_Wall.x2/X_Int);
            end
            zoomed_Curr_Image = current_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int)); %The ROI section of current image
            zoomed_First_Image = first_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int));  %The ROI section of first image
            start_Point = Z_SubAxis(1)*Z_Int;    
            end_Point = Z_SubAxis(end)*Z_Int; 
            Z_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);

            start_Point = X_SubAxis(1)*X_Int;
            end_Point = X_SubAxis(end)*X_Int;
            X_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);
            [X, Z] = meshgrid(X_SubAxis*X_Int, Z_SubAxis*Z_Int);
            [Xq, Zq] = meshgrid(X_SubAxis_Zoomed, Z_SubAxis_Zoomed);
            zoomed_Curr_Image = interp2(X, Z, zoomed_Curr_Image, Xq, Zq, 'spline');
            zoomed_First_Image = interp2(X, Z, zoomed_First_Image, Xq, Zq, 'spline');

            if(display_Off==0)
                axes(image_Zoom_Frame_Axes_Handle);
                cla reset;
                imagesc(X_SubAxis_Zoomed, Z_SubAxis_Zoomed, zoomed_Curr_Image);
            end

            X = xcorr2(zoomed_First_Image, zoomed_Curr_Image);
            CorrCenterX = length(X_SubAxis_Zoomed);
            CorrCenterY = length(Z_SubAxis_Zoomed);

            [max_Corr idx] = max(X(:));
            [shiftY shiftX] = ind2sub(size(X),idx);
            xShiftB = -(shiftX - CorrCenterX)*zoom_Interval;
            yShiftB = (shiftY - CorrCenterY)*zoom_Interval;
        end
    elseif(get(track_Mode_1D, 'Value') == 1) %1D mode tracking
        zoom_Interval_For_Line_Tracking = zoom_Interval/10;
        no_Of_Lines_to_Combine = 3;
        current_Central_Image_Line = mean(current_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis(round(end/2-no_Of_Lines_to_Combine/2))- Origin(1)/X_Int):round(X_SubAxis(round(end/2+no_Of_Lines_to_Combine/2))- Origin(1)/X_Int)),2);
        first_Central_Image_Line = mean(first_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis(round(end/2-no_Of_Lines_to_Combine/2))- Origin(1)/X_Int):round(X_SubAxis(round(end/2+no_Of_Lines_to_Combine/2))- Origin(1)/X_Int)),2); %Central lines of the ROI        
        start_Point = Z_SubAxis(1)*Z_Int;
        end_Point = Z_SubAxis(end)*Z_Int;
        Z_SubAxis_Image_Line = (start_Point:zoom_Interval_For_Line_Tracking:end_Point);
        current_Central_Image_Line = spline(Z_SubAxis*Z_Int, current_Central_Image_Line, Z_SubAxis_Image_Line);
        first_Central_Image_Line = spline(Z_SubAxis*Z_Int, first_Central_Image_Line, Z_SubAxis_Image_Line);
        axes(image_Zoom_Frame_Axes_Handle);
        cla reset;
        hold on;
        plot(Z_SubAxis_Image_Line, first_Central_Image_Line, 'r');
        plot(Z_SubAxis_Image_Line, current_Central_Image_Line, 'b');
        view([90, 90]);
        grid on;
        legend('Reference Line', 'Current Line', 'Location','southeast');
        [yShiftF, max_Corr]  = finddelay_MaxCorr(current_Central_Image_Line, first_Central_Image_Line);
        yShiftF = yShiftF*zoom_Interval_For_Line_Tracking;
        
        if(get(track_Both_Sides_Check, 'Value') ==1)
            start_Point_Posterior = Z_SubAxis(1)*Z_Int +rect_Z_Shift;
            end_Point_Posterior = Z_SubAxis(end)*Z_Int +rect_Z_Shift;
            Z_SubAxis_Image_Line_Posterior = (start_Point_Posterior:zoom_Interval_For_Line_Tracking:end_Point_Posterior); %10 times the image tracking resolution
            current_Central_Image_Line_Posterior = mean(current_Image_Frame(round(Z_SubAxis + rect_Z_Shift/Z_Int - Origin(3)/Z_Int), round(X_SubAxis(round(end/2-no_Of_Lines_to_Combine/2)) + rect_X_Shift/X_Int - Origin(1)/X_Int):round(X_SubAxis(round(end/2+no_Of_Lines_to_Combine/2)) + rect_X_Shift/X_Int - Origin(1)/X_Int)),2);
            first_Central_Image_Line_Posterior = mean(first_Image_Frame(round(Z_SubAxis + rect_Z_Shift/Z_Int - Origin(3)/Z_Int), round(X_SubAxis(round(end/2-no_Of_Lines_to_Combine/2)) + rect_X_Shift/X_Int - Origin(1)/X_Int):round(X_SubAxis(round(end/2+no_Of_Lines_to_Combine/2)) + rect_X_Shift/X_Int- Origin(1)/X_Int)),2);
            current_Central_Image_Line_Posterior = spline(Z_SubAxis*Z_Int+rect_Z_Shift, current_Central_Image_Line_Posterior, Z_SubAxis_Image_Line_Posterior);
            first_Central_Image_Line_Posterior = spline(Z_SubAxis*Z_Int+rect_Z_Shift, first_Central_Image_Line_Posterior, Z_SubAxis_Image_Line_Posterior);
            yShiftB = finddelay(current_Central_Image_Line_Posterior, first_Central_Image_Line_Posterior)*zoom_Interval_For_Line_Tracking;
        end
    end
    
    if(frame_Num >2)
        maxCorr_Arr(frame_Num-1, current_Voltage_Index*current_Time_Index, current_Pressure_Index)= max_Corr;
    	RF_Shift_Arr(frame_Num-1, current_Voltage_Index*current_Time_Index, current_Pressure_Index) = yShiftF - yShiftB;
    end
    set_Axis_Labels();
    displacement_Parameter_View_Changed();
end

function replotForCardiacCycle(current_Dia_Change)
    display_Off = get(display_Images_Check, 'value');
    pData = cardiac_Cycle_Measurement.PData;
    Origin = pData.Origin;
    S = size(current_Image_Frame);
    X_Int = pData.pdeltaX;
    Z_Int = pData.pdeltaZ;
    zoom_Interval = 1/100; %500 points per wavelength
    rect_Z_Shift = tube_Diameter;
    if(current_Dia_Change == -100)
        tube_Diameter= find_Tube_Diameter(0);
        rect_Z_Shift = tube_Diameter;
    end
    rect_X_Shift = 0;
    
    if(display_Off==0)
    axes(image_Frame_Axes_Handle);
    cla;
    imagesc(Origin(1)+ [0:S(2)-1]*X_Int, Origin(3)+[0:S(1)-1]*Z_Int,  non_Linear_Gain_On_Image(current_Image_Frame));
    xlim([Origin(1) Origin(1)+ (S(2)-1)*X_Int]);
    ylim([Origin(3) Origin(3)+(S(1)-1)*Z_Int]);
    hold on;
    scatter(cardiac_Cycle_Measurement.fociix, cardiac_Cycle_Measurement.focii, 100, '+', 'MarkerEdgeColor',[0.7 0.7 0], 'MarkerFaceColor',[0 0 0.7], 'LineWidth',2);
    rectangle('Position', [Image_Rect_Coordinates.x1 Image_Rect_Coordinates.y1 Image_Rect_Coordinates.x2-Image_Rect_Coordinates.x1 Image_Rect_Coordinates.y2-Image_Rect_Coordinates.y1])
    W = Image_Rect_Coordinates.x2-Image_Rect_Coordinates.x1;
    line([Image_Rect_Coordinates.x1+W/2, Image_Rect_Coordinates.x1+W/2], [Image_Rect_Coordinates.y1 Image_Rect_Coordinates.y2]);
    if(get(track_Both_Sides_Check, 'Value') ==1)
        if(get(track_at_Focus_Check,'value') ==1)
            rectangle('Position', [Image_Rect_Coordinates.x1+rect_X_Shift Image_Rect_Coordinates.y1+rect_Z_Shift Image_Rect_Coordinates.x2-Image_Rect_Coordinates.x1 Image_Rect_Coordinates.y2-Image_Rect_Coordinates.y1]);
            line([Image_Rect_Coordinates.x1+W/2, Image_Rect_Coordinates.x1+W/2]+rect_X_Shift, [Image_Rect_Coordinates.y1 Image_Rect_Coordinates.y2]+rect_Z_Shift);
        else
            rectangle('Position', [Image_Rect_Coordinates_Back_Wall.x1 Image_Rect_Coordinates_Back_Wall.y1 Image_Rect_Coordinates_Back_Wall.x2-Image_Rect_Coordinates_Back_Wall.x1 Image_Rect_Coordinates_Back_Wall.y2-Image_Rect_Coordinates_Back_Wall.y1]);
            W = Image_Rect_Coordinates_Back_Wall.x2-Image_Rect_Coordinates_Back_Wall.x1;
            line([Image_Rect_Coordinates_Back_Wall.x1+W/2, Image_Rect_Coordinates_Back_Wall.x1+W/2]+rect_X_Shift, [Image_Rect_Coordinates_Back_Wall.y1 Image_Rect_Coordinates_Back_Wall.y2]);
        end
    end
    end
    
    Z_SubAxis = round(Image_Rect_Coordinates.y1/Z_Int):round(Image_Rect_Coordinates.y2/Z_Int);
    X_SubAxis = round(Image_Rect_Coordinates.x1/X_Int):round(Image_Rect_Coordinates.x2/X_Int);
    zoomed_Curr_Image = current_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int)); %The ROI section of current image
    zoomed_First_Image = first_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int));  %The ROI section of first image
    
    xShiftF = 0;
    yShiftF = 0;
    xShiftB = 0;
    yShiftB = 0;
    
    if(get(track_Mode_2D, 'Value') == 1) %Track 2D sections
        start_Point = Z_SubAxis(1)*Z_Int;    
        end_Point = Z_SubAxis(end)*Z_Int; 
        Z_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);

        start_Point = X_SubAxis(1)*X_Int;
        end_Point = X_SubAxis(end)*X_Int;
        X_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);
        [X, Z] = meshgrid(X_SubAxis*X_Int, Z_SubAxis*Z_Int);
        [Xq, Zq] = meshgrid(X_SubAxis_Zoomed, Z_SubAxis_Zoomed);
        zoomed_Curr_Image = interp2(X, Z, zoomed_Curr_Image, Xq, Zq, 'spline');
        zoomed_First_Image = interp2(X, Z, zoomed_First_Image, Xq, Zq, 'spline');
        
        if(display_Off==0)
            axes(image_Zoom_Frame_Axes_Handle);
            cla reset;
            imagesc(X_SubAxis_Zoomed, Z_SubAxis_Zoomed, zoomed_Curr_Image);
            hold on;
            line([Image_Rect_Coordinates.x1+W/2, Image_Rect_Coordinates.x1+W/2], [Image_Rect_Coordinates.y1 Image_Rect_Coordinates.y2]);
        end

        X = xcorr2(zoomed_First_Image, zoomed_Curr_Image);
        CorrCenterX = length(X_SubAxis_Zoomed);
        CorrCenterY = length(Z_SubAxis_Zoomed);

        [num idx] = max(X(:));
        [shiftY shiftX] = ind2sub(size(X),idx);
        xShiftF = -(shiftX - CorrCenterX)*zoom_Interval;
        yShiftF = (shiftY - CorrCenterY)*zoom_Interval;
        xShiftB = 0;
        yShiftB = 0;
        if(get(track_Both_Sides_Check, 'Value') ==1)
            if(get(track_at_Focus_Check,'value')==1)
                Z_SubAxis  = Z_SubAxis + rect_Z_Shift/Z_Int;
            else
                Z_SubAxis = round(Image_Rect_Coordinates_Back_Wall.y1/Z_Int):round(Image_Rect_Coordinates_Back_Wall.y2/Z_Int);
                X_SubAxis = round(Image_Rect_Coordinates_Back_Wall.x1/X_Int):round(Image_Rect_Coordinates_Back_Wall.x2/X_Int);
            end
            zoomed_Curr_Image = current_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int)); %The ROI section of current image
            zoomed_First_Image = first_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int));  %The ROI section of first image
            start_Point = Z_SubAxis(1)*Z_Int;    
            end_Point = Z_SubAxis(end)*Z_Int; 
            Z_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);

            start_Point = X_SubAxis(1)*X_Int;
            end_Point = X_SubAxis(end)*X_Int;
            X_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);
            [X, Z] = meshgrid(X_SubAxis*X_Int, Z_SubAxis*Z_Int);
            [Xq, Zq] = meshgrid(X_SubAxis_Zoomed, Z_SubAxis_Zoomed);
            zoomed_Curr_Image = interp2(X, Z, zoomed_Curr_Image, Xq, Zq, 'spline');
            zoomed_First_Image = interp2(X, Z, zoomed_First_Image, Xq, Zq, 'spline');

            if(display_Off==0)
                axes(image_Zoom_Frame_Axes_Handle);
                cla reset;
                imagesc(X_SubAxis_Zoomed, Z_SubAxis_Zoomed, zoomed_Curr_Image);
            end

            X = xcorr2(zoomed_First_Image, zoomed_Curr_Image);
            CorrCenterX = length(X_SubAxis_Zoomed);
            CorrCenterY = length(Z_SubAxis_Zoomed);

            [num idx] = max(X(:));
            [shiftY shiftX] = ind2sub(size(X),idx);
            xShiftB = -(shiftX - CorrCenterX)*zoom_Interval;
            yShiftB = (shiftY - CorrCenterY)*zoom_Interval;
        end
    elseif(get(track_Mode_1D, 'Value') == 1) %1D mode tracking
        zoom_Interval_For_Line_Tracking = zoom_Interval/10;
        no_Of_Lines_to_Combine = 3;
        current_Central_Image_Line = mean(current_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis(round(end/2-no_Of_Lines_to_Combine/2))- Origin(1)/X_Int):round(X_SubAxis(round(end/2+no_Of_Lines_to_Combine/2))- Origin(1)/X_Int)),2);
        first_Central_Image_Line = mean(first_Image_Frame(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis(round(end/2-no_Of_Lines_to_Combine/2))- Origin(1)/X_Int):round(X_SubAxis(round(end/2+no_Of_Lines_to_Combine/2))- Origin(1)/X_Int)),2); %Central lines of the ROI        
        start_Point = Z_SubAxis(1)*Z_Int;
        end_Point = Z_SubAxis(end)*Z_Int;
        Z_SubAxis_Image_Line = (start_Point:zoom_Interval_For_Line_Tracking:end_Point);
        current_Central_Image_Line = spline(Z_SubAxis*Z_Int, current_Central_Image_Line, Z_SubAxis_Image_Line);
        first_Central_Image_Line = spline(Z_SubAxis*Z_Int, first_Central_Image_Line, Z_SubAxis_Image_Line);
        axes(image_Zoom_Frame_Axes_Handle);
        cla reset;
        hold on;
        plot(Z_SubAxis_Image_Line, first_Central_Image_Line, 'r');
        plot(Z_SubAxis_Image_Line, current_Central_Image_Line, 'b');
        view([90, 90]);
        grid on;
        legend('Reference Line', 'Current Line', 'Location','southeast');
        [yShiftF, max_Corr]  = finddelay_MaxCorr(current_Central_Image_Line, first_Central_Image_Line);
        yShiftF = yShiftF*zoom_Interval_For_Line_Tracking;
        
        if(get(track_Both_Sides_Check, 'Value') ==1)
            start_Point_Posterior = Z_SubAxis(1)*Z_Int +rect_Z_Shift;
            end_Point_Posterior = Z_SubAxis(end)*Z_Int +rect_Z_Shift;
            Z_SubAxis_Image_Line_Posterior = (start_Point_Posterior:zoom_Interval_For_Line_Tracking:end_Point_Posterior); %10 times the image tracking resolution
            current_Central_Image_Line_Posterior = mean(current_Image_Frame(round(Z_SubAxis + rect_Z_Shift/Z_Int - Origin(3)/Z_Int), round(X_SubAxis(round(end/2-no_Of_Lines_to_Combine/2)) + rect_X_Shift/X_Int - Origin(1)/X_Int):round(X_SubAxis(round(end/2+no_Of_Lines_to_Combine/2)) + rect_X_Shift/X_Int - Origin(1)/X_Int)),2);
            first_Central_Image_Line_Posterior = mean(first_Image_Frame(round(Z_SubAxis + rect_Z_Shift/Z_Int - Origin(3)/Z_Int), round(X_SubAxis(round(end/2-no_Of_Lines_to_Combine/2)) + rect_X_Shift/X_Int - Origin(1)/X_Int):round(X_SubAxis(round(end/2+no_Of_Lines_to_Combine/2)) + rect_X_Shift/X_Int- Origin(1)/X_Int)),2);
            current_Central_Image_Line_Posterior = spline(Z_SubAxis*Z_Int+rect_Z_Shift, current_Central_Image_Line_Posterior, Z_SubAxis_Image_Line_Posterior);
            first_Central_Image_Line_Posterior = spline(Z_SubAxis*Z_Int+rect_Z_Shift, first_Central_Image_Line_Posterior, Z_SubAxis_Image_Line_Posterior);
            yShiftB = finddelay(current_Central_Image_Line_Posterior, first_Central_Image_Line_Posterior)*zoom_Interval_For_Line_Tracking;
        end
    end
    
    maxCorr_Arr(frame_Num, 1, 1)= max_Corr;
    RF_Shift_Arr(frame_Num,1, 1) = current_Dia_Change+ (yShiftF - yShiftB);
    set_Axis_Labels();
    displacement_Parameter_View_Changed();
end


function tube_Diameter = find_Tube_Diameter(pressure_Index)
    if(cardiac_Cycle_Mode ==0)
        [~,MI] = max(voltage_Levels);
        first_Image = getImageFrame(pressure_Index, 2,MI);
        if(sum(first_Image(:,10))==0)
            first_Image = getImageFrame(pressure_Index, 1,MI);
        end
        pData = measurement.PData;
    else
        first_Image = getImageFrame_For_Cardiac_Cycle_Data(1);
        pData = cardiac_Cycle_Measurement.PData;
    end
    
    Origin = pData.Origin;
    X_Int = pData.pdeltaX;
    Z_Int = pData.pdeltaZ;
    if(get(track_at_Focus_Check,'value') ==0)
        try
            Image_Rect_Coordinates_Back_Wall.y2;
        catch
            tube_Diameter = 0;
            return;
        end
        tube_Diameter = abs((Image_Rect_Coordinates.y1-Image_Rect_Coordinates_Back_Wall.y1));
        return
    end
    interpolation_Factor = 3;
    interpolated_Image = interp2(first_Image,interpolation_Factor);
    
    central_Line = 0;
    try
        central_Line = interpolated_Image(:,1 + 2^interpolation_Factor *round(((Image_Rect_Coordinates.x1+Image_Rect_Coordinates.x2)/2- Origin(1))/X_Int));
    catch
        central_Line = interpolated_Image(:,round(end/2));
    end
    
    central_Line_For_Dia_MMT = smooth(central_Line,100);
    central_Line_For_Thickness_MMT = smooth(central_Line);
    normalized_Central_Line = central_Line_For_Dia_MMT/max(central_Line_For_Dia_MMT);
    S = 1;
    count =1;
    while(S<2)
        P = peakdet(normalized_Central_Line,0.5/count);
        S = size(P);
        S = S(1,1);
        count = count+1;
        if(count>10)
            break
        end
    end

    [~, descend_Index] = sort(P(:,2), 'descend');
    tube_Diameter = Z_Int*abs(P(descend_Index(2),1)-P(descend_Index(1),1))/(2^interpolation_Factor);
    
%     two_mm_Points = round((2*(2^interpolation_Factor)/(waveLength*Z_Int)));
%     normalized_Central_Line = central_Line_For_Thickness_MMT/max(central_Line_For_Thickness_MMT);
%     far_Wall_Signal = normalized_Central_Line(P(descend_Index(1),1)-two_mm_Points:P(descend_Index(1),1)+two_mm_Points);
%     far_Wall_Signal_Derivative = diff(smooth(diff(far_Wall_Signal)));
%     [~, Mx] = max(far_Wall_Signal_Derivative);
%     [~, Mn] = min(far_Wall_Signal_Derivative);
%     thickness = Z_Int*abs(Mx-Mn)/(2^interpolation_Factor);
%     tube_Diameter= tube_Diameter+thickness;
end

function [adjusted_Image_Frame] = non_Linear_Gain_On_Image(input_Image_Frame)
    Mn = min(min(input_Image_Frame));
    input_Image_Frame = input_Image_Frame-Mn;
    Mx = max(max(input_Image_Frame));
    input_Image_Frame = input_Image_Frame/Mx;
    adjusted_Image_Frame = log(input_Image_Frame+mean(mean(input_Image_Frame)));
end

function [maxPtsX, maxPtsZ, curvature] = getMaxPointsImageCols(X_SubAxis_current_Image, Z_SubAxis_Curr_Image, zoomed_Curr_Image)
    maxPtsX = X_SubAxis_current_Image;
    for i = 1:length(X_SubAxis_current_Image)
        max_Indices = find(zoomed_Curr_Image(:,i)> max(zoomed_Curr_Image(:,i))*0.9);
        maxPtsZ(i) = Z_SubAxis_Curr_Image(round(median(max_Indices)));
    end
    curvature = maxPtsZ(round(end/2))- (maxPtsZ(round(end/2 - end/15)) + maxPtsZ(round(end/2 + end/15)))/2;
end



function [maxtab, mintab]= peakdet(v, delta, x)
maxtab = [];
mintab = [];

v = v(:); % Just in case this wasn't a proper vector

if nargin < 3
  x = (1:length(v))';
else 
  x = x(:);
  if length(v)~= length(x)
    error('Input vectors v and x must have same length');
  end
end
  
if (length(delta(:)))>1
  error('Input argument DELTA must be a scalar');
end

if delta <= 0
  error('Input argument DELTA must be positive');
end

mn = Inf; mx = -Inf;
mnpos = NaN; mxpos = NaN;

lookformax = 1;

for i=1:length(v)
  this = v(i);
  if this > mx, mx = this; mxpos = x(i); end
  if this < mn, mn = this; mnpos = x(i); end
  
  if lookformax
    if this < mx-delta
      maxtab = [maxtab ; mxpos mx];
      mn = this; mnpos = x(i);
      lookformax = 0;
    end  
  else
    if this > mn+delta
      mintab = [mintab ; mnpos mn];
      mx = this; mxpos = x(i);
      lookformax = 1;
    end
  end
end
end

function set_Axis_Labels()
xlabel(image_Frame_Axes_Handle, 'Width in Wavelengths');
ylabel(image_Frame_Axes_Handle, 'Depth in Wavelengths');

xlabel(image_Zoom_Frame_Axes_Handle, 'Width in Wavelengths');
ylabel(image_Zoom_Frame_Axes_Handle, 'Depth in Wavelengths');

if(get(K_Plot_But, 'Value') ==1)
    xlabel(shift_Display_Axes, 'Voltage^2\timesPulse duration');
    ylabel(shift_Display_Axes, strvcat('Displacement in Wavelengths', 'for first tracking frame'));
elseif(get(recovery_Plot_But, 'Value') ==1)
    xlabel(shift_Display_Axes, 'Time in \mus');
    ylabel(shift_Display_Axes, 'Displacement in Wavelengths');
end

end

function  actOnMouseMove(varargin)
    cursorPoint = get(image_Frame_Axes_Handle, 'CurrentPoint');
    curX = cursorPoint(1,1);
    curY = cursorPoint(1,2);
    
    xLimits = get(image_Frame_Axes_Handle, 'xlim');
    yLimits = get(image_Frame_Axes_Handle, 'ylim');

    if (curX > min(xLimits) && curX < max(xLimits) && curY > min(yLimits) && curY < max(yLimits))
        set(mother_Window, 'Pointer', 'crosshair');
    else
        set(mother_Window, 'Pointer', 'arrow');
    end
end

function voltageChange_Callback(varargin)
    current_Voltage_Index = get(voltageList,'Value');
    first_Image_Frame = getImageFrame(current_Pressure_Index, 1, current_Voltage_Index*current_Time_Index);
    if(track_Stop ==1)
        frame_Slider_Callback();
        replot_Everything();
    end
end

function timeChange_Callback(varargin)
    current_Time_Index = get(timeList,'Value');
    first_Image_Frame = getImageFrame(current_Pressure_Index, 1, current_Voltage_Index*current_Time_Index);
    if(track_Stop ==1)
        frame_Slider_Callback();
        replot_Everything();
    end
end

function pressureChange_Callback(varargin)
    current_Pressure_Index = get(pressureList,'Value');
    set(voltageList,'String', num2str((measurement.seqData(current_Pressure_Index).V)'))
    set(timeList,'String', num2str((measurement.seqData(current_Pressure_Index).T)'))
    timing_List_in_us = measurement.seqData(current_Pressure_Index).timingListus;
    if(get(track_at_Focus_Check, 'Value') ==1)
        Image_Rect_Coordinates = find_Rect(current_Image_Frame, image_Frame_Axes_Handle, measurement.seqData(current_Pressure_Index).fociix, measurement.seqData(current_Pressure_Index).focii, zoom_Level);
        if(get(track_Both_Sides_Check, 'Value') ==1)
            tube_Diameter = find_Tube_Diameter(current_Pressure_Index);
        end
    else
        frame_Slider_Callback();
        msgbox('Click to set Front Wall');
        wall_Selection_Counter =1;
        waitForFrontWallRectSet();
        wall_Selection_Counter=2;
        msgbox('Click to set Back Wall');
        waitForBackWallRectSet();
    end
    
    if(track_Stop ==1)
        frame_Slider_Callback();
    end
end

function push_On_Check_Callback(varargin)
    if(get(push_On_Check,'Value') == 0)
        push_On_During_View = 0;
    else
        push_On_During_View = 1;
    end
    evalin('base', ['push_On_During_View = ', num2str(push_On_During_View)]);
end

function show_Live_Images_Callback(varargin)
    if (get(show_Live_Images,'Value') == 1)
        set(push_On_Check,'Enable','off');
        set(show_Ref_Frames,'Enable','off');
        evalin('base', 'user_Fig_Handle = []');
        assignin('base', 'user_Fig_Handle', image_Frame_Axes_Handle);
        assignin('base', 'zoomed_Fig_Handle', image_Zoom_Frame_Axes_Handle);
        assignin('base', 'exit', 0);
        evalin('base','Mcr_GuiHide = 1') %Control panel hide
        evalin('base','Mcr_DisplayHide = 1'); %Display window hide
        assignin('base', 'time_Between_Acq_in_Viewer_Mode_Text',  str2double(get(time_Between_Acq_in_Viewer_Mode_Text,'string')));
        evalin('base','livePushView');
    end
    if (get(show_Live_Images,'Value') == 0)
        set(push_On_Check,'Enable','on');
        set(show_Ref_Frames,'Enable','on');
        assignin('base', 'exit', 1);
    end
end

function set_Trans_Freq(varargin)
    transducer_Frequency_in_Hz = str2num(get(trans_Freq_Text,'string'));
    waveLength =  1000*speed_Of_Sound/transducer_Frequency_in_Hz; 
    evalin('base', ['transducer_Frequency_in_Hz =', num2str(transducer_Frequency_in_Hz)]);
    evalin('base', 'Trans.name = ''L7-4''; Trans.frequency = transducer_Frequency_in_Hz/1000000;  Trans.units = ''wavelengths''; Trans = computeTrans(Trans); wavelength_in_mm = 1000*Resource.Parameters.speedOfSound/transducer_Frequency_in_Hz; Trans.maxHighVoltage = 100;');
    evalin('base', ['center_of_Vision = ', num2str(center_of_Vision_mm), '/wavelength_in_mm;']);
    evalin('base', ['end_RF_Depth = ', num2str(end_RF_Depth_mm), '/wavelength_in_mm;']);
    evalin('base','PData(1).Size(1,1) = 2*round((16/(wavelength_in_mm*PData(1).pdeltaZ))/2)+1; PData(1).Size(1,2) = 2*round((16/(wavelength_in_mm*PData(1).pdeltaX))/2)+1; PData(1).Size(1,3) = 1;');
    evalin('base','PData(1).Origin = [-8/wavelength_in_mm,0,center_of_Vision - 8/wavelength_in_mm]; '); %PData(1).Size are all set to odd for perfect allignment on display
end

function set_Speed_of_Sound(varargin)
    speed_Of_Sound = str2num(get(set_Speed_of_Sound_Text,'string'));
    waveLength =  1000*speed_Of_Sound/transducer_Frequency_in_Hz; 
    evalin('base', ['Resource.Parameters.speedOfSound =', num2str(speed_Of_Sound)]);
    evalin('base', 'Trans.name = ''L7-4''; Trans.frequency = transducer_Frequency_in_Hz/1000000;  Trans.units = ''wavelengths''; Trans = computeTrans(Trans); wavelength_in_mm = 1000*Resource.Parameters.speedOfSound/transducer_Frequency_in_Hz; Trans.maxHighVoltage = 100;');
    evalin('base', ['center_of_Vision = ', num2str(center_of_Vision_mm), '/wavelength_in_mm;']);
    evalin('base', ['end_RF_Depth = ', num2str(end_RF_Depth_mm), '/wavelength_in_mm;']);
    evalin('base','PData(1).Size(1,1) = 2*round((16/(wavelength_in_mm*PData(1).pdeltaZ))/2)+1; PData(1).Size(1,2) = 2*round((16/(wavelength_in_mm*PData(1).pdeltaX))/2)+1; PData(1).Size(1,3) = 1;');
    evalin('base','PData(1).Origin = [-8/wavelength_in_mm,0,center_of_Vision - 8/wavelength_in_mm]; '); %PData(1).Size are all set to odd for perfect allignment on display
end

function show_Ref_Frames_Callback(varargin)
    evalin('base', ['switch_Between_Ref_Tracking = ', num2str(get(show_Ref_Frames, 'Value'))] );
end

function TGC_On_Callback(varargin)
    evalin('base', ['TGC_On = ', num2str(get(TGC_On_Check, 'Value'))]);
end

function acquire_Data_Callback(varargin)
    eval(['voltage_Levels =(', get(voltage_List_Command,'String'),')']);
    eval(['time_List =(', get(time_List_Command,'String'),')']);
    evalin('base','voltage_Levels = []');
    assignin('base','voltage_Levels', voltage_Levels);
    evalin('base','time_List = []');
    assignin('base','time_List', time_List);
    %Check for expected length of voltage and time arrays. Only one of them should sweep.
    time_Sweep_Mode_On = get(enable_Time_Sweep,'value');
    voltage_Sweep_Mode_On = get(enable_Voltage_Sweep,'value');
    if(length(time_List)>1 && voltage_Sweep_Mode_On ==1)
        msgbox('Time sweep not supported in voltage sweep mode');
        return;
    elseif(length(voltage_Levels)>1 && time_Sweep_Mode_On ==1)
        msgbox('Voltage sweep not supported in time sweep mode');
        return;
    end
    
    eval(['pressure_Levels =(', get(pressure_List_Command,'String'),')']);
    assignin('base','num_of_Frames_Per_Push_Cycle', str2num(get(num_Of_Frames_Per_Voltage,'String')));
    num_of_Frames_Per_Push_Cycle = str2num(get(num_Of_Frames_Per_Voltage,'String'));
    measurement = struct;
    RF_Shift_Arr = zeros(num_of_Frames_Per_Push_Cycle-1,length(voltage_Levels),length(pressure_Levels));
    
    for i = 1:length(pressure_Levels)
        pressure_Input_Text = inputdlg(['Please set the pressure to ', num2str(pressure_Levels(i)),' mmHg'],'Pressure input',1,{num2str(pressure_Levels(i))});
        if(isempty(pressure_Input_Text))
            disp('Measurement aborted.');
            return;
        end
        evalin('base','focusSetSeq');  %Attempt to autofocus.
        msgbox('Click on the image to set the focal point.');
        disp('Waiting for user focus set ...');
        waitForFocusSet();
        pressure_Levels(i) = str2num(pressure_Input_Text{1});
        evalin('base', ['pressure_In_Tube =', num2str(pressure_Levels(i))]);
        evalin('base', 'user_Fig_Handle = []');
        assignin('base', 'user_Fig_Handle', image_Frame_Axes_Handle);
        evalin('base', 'zoomed_Fig_Handle = []');
        assignin('base', 'zoomed_Fig_Handle', image_Zoom_Frame_Axes_Handle);
        assignin('base','sweep_Mode', voltage_Sweep_Mode_On);
        assignin('base','voltage_Levels', voltage_Levels);
        assignin('base','time_List', time_List);
        assignin('base','num_of_Frames_Per_Push_Cycle', str2num(get(num_Of_Frames_Per_Voltage,'String')));
        evalin('base', 'viewer_Mode = 0');
        evalin('base','pushSequence2');
        measurement.seqData(i).P = pressure_Levels(i);
        measurement.seqData(i).imageData = evalin('base','ImgData{1}');
        measurement.seqData(i).IQData = evalin('base','IQData{1}');
        measurement.seqData(i).RFData = evalin('base','RcvData{1}');
        measurement.seqData(i).V = evalin('base','voltage_Levels');
        measurement.seqData(i).T = evalin('base','time_List')*(duration_of_Each_SubPulse_in_us+gap_Between_Pulses_in_us);
        measurement.seqData(i).focii = evalin('base','focal_Length');
        measurement.seqData(i).fociix = evalin('base','focal_X');
        measurement.seqData(i).timingListus = evalin('base', 'timing_List_in_us');
        measurement.seqData(i).push_Start_End = evalin('base', 'push_Timing_Start_End');
    end
    measurement.num_OF_Frames_Per_Push = num_of_Frames_Per_Push_Cycle;
    measurement.rows_Per_Frame = evalin('base','Resource.RcvBuffer(1).rowsPerFrame')/(2*evalin('base','num_of_Frames_Per_Push_Cycle'));
    measurement.points_Per_RF_Wavelength = evalin('base', 'RF_Points_Per_Wavelength');
    measurement.points_Per_IQ_Wavelength = evalin('base', 'IQ_Points_Per_Wavelength');
    measurement.RF_Shift_Arr = RF_Shift_Arr;
    measurement.PData = evalin('base','PData');
    measurement.sweepMode =  voltage_Sweep_Mode_On;
    measurement.speed_Of_Sound = speed_Of_Sound;
    measurement.waveLength =  1000*speed_Of_Sound/transducer_Frequency_in_Hz; 
    measurement.duration_of_Each_SubPulse_in_us = duration_of_Each_SubPulse_in_us;
    measurement.gap_Between_Pulses_in_us = gap_Between_Pulses_in_us;
    cardiac_Cycle_Mode =0; 
    
    set(voltageList,'String', num2str((measurement(1).seqData(1).V)'));
    set(timeList,'String', num2str((measurement(1).seqData(1).T)'));
    time_List = measurement.seqData(i).T;
    timing_List_in_us =  measurement.seqData(1).timingListus;
    loadPressureList;
    set(frame_Slider,'Max',num_of_Frames_Per_Push_Cycle+0.5);
    set(frame_Slider,'Value',1);
    
    frame_Num = floor(get(frame_Slider,'Value'));
    current_Image_Frame = getImageFrame(current_Pressure_Index, frame_Num,current_Voltage_Index*current_Time_Index);
    first_Image_Frame = getImageFrame(current_Pressure_Index, 1,current_Voltage_Index*current_Time_Index);
    Image_Rect_Coordinates = find_Rect(current_Image_Frame, image_Frame_Axes_Handle, measurement.seqData(i).fociix, measurement.seqData(i).focii, zoom_Level);
    replot_Everything;
end

function acquire_Cardiac_Cycle_Callback(varargin)
%     evalin('base','focusSetSeq');  %Attempt to autofocus.
%     msgbox('Click on the image to set the focal point.');
%     disp('Waiting for user focus set ...');
%     waitForFocusSet();
    cardiac_Cycle_Mode =1; 
    evalin('base', 'viewer_Mode=1;');
    assignin('base','pings_per_Second', str2num(get(pings_Per_Second_Text,'String')));
    assignin('base','cardiac_Cycle_Acq_Duration', str2num(get(duration_Of_Cardiac_Acq_Text,'String')));
    assignin('base','total_No_of_Pings', round(str2num(get(pings_Per_Second_Text,'String'))*(str2num(get(duration_Of_Cardiac_Acq_Text,'String'))/1000)));
    assignin('base','cardiac_Push_Voltage', str2num(get(cardiac_Probe_Voltage_Text,'String')));
    assignin('base','no_Frames_Per_Cardiac_Push', str2num(get(no_of_Frames_Per_Cardiac_Push_Text,'String')));
    evalin('base','Cardiac_Cycle_Probe_Multiflash');
    cardiac_Cycle_Measurement.ping_Rate = evalin('base','pings_per_Second');
    cardiac_Cycle_Measurement.total_No_of_Pings = evalin('base','total_No_of_Pings');
    cardiac_Cycle_Measurement.ping_Pressure_List = evalin('base','ping_Pressure_List');
    cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push = evalin('base','no_Frames_Per_Cardiac_Push');
    cardiac_Cycle_Measurement.imageData = evalin('base','ImgData{1}');
    cardiac_Cycle_Measurement.IQData = evalin('base','IQData{1}');
    cardiac_Cycle_Measurement.RFData = evalin('base','RcvData{1}');
    cardiac_Cycle_Measurement.V = evalin('base','cardiac_Push_Voltage');
    cardiac_Cycle_Measurement.Duration = evalin('base','cardiac_Cycle_Acq_Duration');
    cardiac_Cycle_Measurement.ping_Time_Stamps = evalin('base','timing_List_in_us');
    cardiac_Cycle_Measurement.focii = evalin('base','focal_Length');
    cardiac_Cycle_Measurement.fociix = evalin('base','focal_X');
    cardiac_Cycle_Measurement.PData = evalin('base','PData');
    cardiac_Cycle_Measurement.speed_Of_Sound = speed_Of_Sound;
    cardiac_Cycle_Measurement.waveLength =  1000*speed_Of_Sound/transducer_Frequency_in_Hz; 
    set(frame_Slider,'Max',cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push*cardiac_Cycle_Measurement.total_No_of_Pings +0.5);
    set(frame_Slider,'Value',1);
end

function save_Cardiac_Cycle_Callback(varargin)
    [FileName,PathName] = uiputfile('Last_Measurement.card','Save Cardiac Cycle Mmt File');
    if(FileName == 0)
        disp('file saving cancelled');
        return
    end

    disp('Saving cardiac cycle mmt file...');
    save([PathName, FileName],'cardiac_Cycle_Measurement', '-v7.3');
    disp('File is saved now');
end

function save_Cardiac_Cycle_Analysis_Callback(varargin)
    analysis_Data.RF_Shift_Arr = RF_Shift_Arr;
    save(current_File_Path,'analysis_Data','-append')
end

function waitForFocusSet()
    focalLength = 0;
    while(focalLength ==0)
        pause(0.1);
        drawnow;
    end
end

function waitForFrontWallRectSet()
    Image_Rect_Coordinates.x1 = 0;
    while(Image_Rect_Coordinates.x1 ==0)
        pause(0.1);
        drawnow;
    end
end

function waitForBackWallRectSet()
    Image_Rect_Coordinates_Back_Wall.x1 =0;
    while(Image_Rect_Coordinates_Back_Wall.x1 ==0)
        pause(0.1);
        drawnow;
    end
end

function push_Viewer_Voltage_Slider_Callback(varargin)
    push_Viewer_Voltage = get(push_Viewer_Voltage_Slider,'Value');
    evalin('base',['push_Viewer_Voltage = ', num2str(push_Viewer_Voltage)]);
    set(push_Viewer_Voltage_Slider_Label,'String',['Push voltage during view = ' num2str(push_Viewer_Voltage)]);
end

function operationMode_Callback(varargin)
    if (get(operation_Mode,'Value') == 1) %Sim Mode
        set(acquire_Data_Button,'Enable', 'on');
        evalin('base', 'Resource.Parameters.simulateMode = 1;');  % Run in simulation mode
    elseif(get(operation_Mode,'Value') == 2) %File Mode
        set(acquire_Data_Button,'Enable', 'off');
        [FileName,PathName] = uigetfile('*.mat','Select a recorded data file');
        if(FileName == 0)
            set(operation_Mode,'Value',1);
            set(acquire_Data_Button,'Enable', 'on');
            return
        end
        load_MMT_File([PathName, FileName]);
        evalin('base', 'Resource.Parameters.simulateMode = 1;');  % Run in simulation mode
    else %Data acq Mode
        set(acquire_Data_Button,'Enable', 'on');
        evalin('base', 'Resource.Parameters.simulateMode = 0;');  % Run in simulation mode
    end
end

function save_Data_Callback(varargin)
    [FileName,PathName] = uiputfile('Last_Measurement.mat','Save Measurement File');
    if(FileName == 0)
        disp('file saving cancelled');
        return
    end

    disp('Saving measurement file...');
    save([PathName, FileName],'measurement', '-v7.3');
    disp('File is saved now');
end

function load_MMT_File(file_Path)
    evalin('base', ['load(''',file_Path,''',''-mat'')']);
    current_File_Path = file_Path;
    [pathstr,name,ext] = fileparts(current_File_Path);
    if(strcmp(ext,'.card')==1)
        cardiac_Cycle_Measurement = evalin('base','cardiac_Cycle_Measurement');
        cardiac_Cycle_Mode =1;
        frame_Num =1;
        try
            RF_Shift_Arr = evalin('base','analysis_Data.RF_Shift_Arr');
            frame_Num = cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push*cardiac_Cycle_Measurement.total_No_of_Pings;
        catch
        end
        set(frame_Slider,'Max',cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push*cardiac_Cycle_Measurement.total_No_of_Pings +0.5);
        set(frame_Slider,'Value',frame_Num);
        current_Image_Frame = getImageFrame_For_Cardiac_Cycle_Data(frame_Num);
        speed_Of_Sound =cardiac_Cycle_Measurement.speed_Of_Sound;
        set(set_Speed_of_Sound_Text,'String',num2str(cardiac_Cycle_Measurement.speed_Of_Sound))
        displacement_Parameter_View_Changed
    else
        measurement = evalin('base','measurement');
        cardiac_Cycle_Mode =0; 
        try
            recovery_Arr = evalin('base','analysis_Data.recovery_Arr');
            set(merge_Same_Pressures_Check_Box,'value', evalin('base','analysis_Data.merged_Pressures_Check'));
            analyze_Freq_Callback();
        catch
        end

        evalin('base', 'clear measurement');
        evalin('base', 'clear analysis_Data');
        set(voltageList,'String', num2str((measurement.seqData(1).V)'));
        current_Voltage_Index = 1;
        set(voltageList,'Value', current_Voltage_Index);
        voltage_Levels = measurement.seqData(1).V;
        set(timeList,'String', num2str((measurement.seqData(1).T)'));
        current_Time_Index = 1;
        set(timeList,'Value', current_Time_Index);
        time_List = measurement.seqData(1).T;
        voltage_Levels = measurement.seqData(1).V;
        num_of_Frames_Per_Push_Cycle = measurement.num_OF_Frames_Per_Push;
        timing_List_in_us = measurement.seqData(1).timingListus;
        set(frame_Slider,'Max',num_of_Frames_Per_Push_Cycle+0.5);

        loadPressureList

        frame_Num = floor(get(frame_Slider,'Value'));
        current_Image_Frame = getImageFrame(current_Pressure_Index, frame_Num,current_Voltage_Index);

        Image_Rect_Coordinates = find_Rect(current_Image_Frame, image_Frame_Axes_Handle, measurement.seqData(1).fociix, measurement.seqData(1).focii, zoom_Level);
        try
            RF_Shift_Arr = measurement.RF_Shift_Arr;
        catch
            RF_Shift_Arr = zeros(num_of_Frames_Per_Push_Cycle-1,length(voltage_Levels)*length(time_List),length(pressure_Levels));
        end
        speed_Of_Sound = measurement.speed_Of_Sound;
        set(set_Speed_of_Sound_Text,'String',num2str(measurement.speed_Of_Sound));
        replot_Everything();
    end
end

function loadPressureList
    pressure_Str = [];
    pressure_Levels = 0;
    for i =1:length(measurement.seqData)
        pressure_Levels(i) = measurement.seqData(i).P;
        pressure_Str = strvcat(pressure_Str,num2str(measurement.seqData(i).P));
    end
    set(pressureList,'String', pressure_Str)
    set(pressureList,'Value',1);
    current_Pressure_Index = 1;
end

function analyze_Freq_Callback(varargin)
    temp_Pressure_List =[];
    temp_Recovery_Arr = [];
    if(get(merge_Same_Pressures_Check_Box,'value') ==1)
        temp_Pressure_List = unique(pressure_Levels,'First');
        temp_Recovery_Arr = zeros(length(recovery_Arr), length(temp_Pressure_List));
        for i = 1:length(temp_Pressure_List)
            temp_Recovery_Arr(:,i) = (mean((recovery_Arr(:, find(pressure_Levels == temp_Pressure_List(i))))'))';
        end
    else
        temp_Pressure_List = pressure_Levels;
        temp_Recovery_Arr = recovery_Arr;
    end
    time_List_to_Save = timing_List_in_us([1, 3:num_of_Frames_Per_Push_Cycle]);
    plot_Colors = rand(length(temp_Pressure_List),3);
    axes(shift_Display_Axes);
    cla;
    hold on;
    for i = 1:length(temp_Pressure_List)
        plot(timing_List_in_us([1, 3:num_of_Frames_Per_Push_Cycle]), temp_Recovery_Arr(:,i), 'color',plot_Colors(i,:));
    end
    legend(num2str(temp_Pressure_List'), 'Location','northeast');
    grid on;
    xlabel('Time (in \mus)');
    ylabel('Displacement in Wavelengths');

    freq_Peaks = zeros(length(temp_Pressure_List),2);
    axes(analysis_Axes_Handle);
    cla;
    hold on;
    current_Resolution = 1/(mean(diff(time_List_to_Save))*(10^-6)*length(temp_Recovery_Arr(2:end, 1)));
    freq_Resolution_Required_Hz = 1;
    interpolation_Freq_Bins = (0:freq_Resolution_Required_Hz:10000);
    start_Freq = 900;
    end_Freq = 2000;
    range_Indices = find(interpolation_Freq_Bins>= start_Freq & interpolation_Freq_Bins<= end_Freq);
    freq_Analysis_Range = start_Freq:freq_Resolution_Required_Hz:end_Freq;
    freq_Arr = zeros(length(temp_Pressure_List),length(freq_Analysis_Range));

    for pressure_Index = 1:length(temp_Pressure_List)
        fft_Start_Index = str2num(get(fft_Start_Index_Text,'String'));
        amplitude_Arr = temp_Recovery_Arr(fft_Start_Index:end, pressure_Index);
        fft_Plot = abs(fft(amplitude_Arr-mean(amplitude_Arr)));
        fft_Plot_Interpolated = interp1((0:length(fft_Plot)-1)*current_Resolution,fft_Plot, interpolation_Freq_Bins, 'spline'); %look until 10000 Hz
        freq_Arr(pressure_Index,:) = fft_Plot_Interpolated(range_Indices)-mean(fft_Plot_Interpolated(range_Indices));
        plot(freq_Analysis_Range ,freq_Arr(pressure_Index,:)/max(freq_Arr(pressure_Index,:)),'color',plot_Colors(pressure_Index,:),'LineWidth',2);
        try
            fP = peakdet(freq_Arr(pressure_Index,:)/max(freq_Arr(pressure_Index,:)), 0.2); %Expecting only one row
            freq_Peaks(pressure_Index, :)= fP(end,:);
            freq_Peaks(pressure_Index, 1) = (freq_Peaks(pressure_Index, 1)-1)*freq_Resolution_Required_Hz + start_Freq;
        catch
            freq_Peaks(pressure_Index, 1) = -1;
        end
    end
    freq_Peaks
    xlim auto
    ylim auto
    legend(num2str(temp_Pressure_List'), 'Location','northeast');
    grid on;
    xlabel('Frequency (in Hz)');
    ylabel('Normalized Value');
    title('FFT of Recovery Plot');
    axes(image_Zoom_Frame_Axes_Handle);
    view([0, 90]);
    cla;
    plot(temp_Pressure_List, (freq_Peaks(:,1)).^2);
    xlabel('Pressure (mmHg)');
    ylabel('Frequency^2 (in Hz^2)');
    grid on;
    
    save('tracking_Data','temp_Pressure_List', 'time_List_to_Save','temp_Recovery_Arr', 'freq_Analysis_Range', 'freq_Arr', 'freq_Peaks');
end

function mean_Array = delay_Mean_And_Norm(central_Lines)
    S = size(central_Lines);
    for i =2:S(2)
        d = finddelay(central_Lines(:,i), central_Lines(:,1));
        central_Lines(:,i) = circshift(central_Lines(:,i),d);
    end
    mean_Array = smooth(abs(hilbert((mean(central_Lines,2)))), round(length(central_Lines)/100));
    mean_Array = mean_Array/max(abs(mean_Array));
end

function [max_Dia, thickness] = get_Vertical_Dia(RFArray, Central_Line_Loc, mmSamples)
    S = size(RFArray);
    max_Dia = 0;
    max_Dia_Line = 0;
    max_Dia_Near_Wall = 0;
    max_Dia_Far_Wall = 0;
    for i =Central_Line_Loc-mmSamples:Central_Line_Loc+mmSamples
        normalized_Current_Line = delay_Mean_And_Norm(RFArray(:,i)- mean(RFArray(:,i)));
        normalized_Current_Line = normalized_Current_Line(50:end-50);
        %normalized_Current_Line = abs(smooth(normalized_Current_Line/max(abs(normalized_Current_Line))));
        P = peakdet(normalized_Current_Line, 0.2);
        Sp = size(P);
        if(Sp(1) ==2)
            current_Dia = P(2,1)-P(1,1);
            if(max_Dia < current_Dia)
                max_Dia = current_Dia;
                max_Dia_Line = normalized_Current_Line;
                near_Wall_Peak_Loc = P(1,1);
                far_Wall_Peak_Loc = P(2,1);
                axes(image_Zoom_Frame_Axes_Handle);
                view([0, 90]);
                cla;
                plot(normalized_Current_Line);
            end
        end
    end
    %Threshold for finding only four zero crossings
    threshold = 0.8;
    Sz = 0;
    while(1)
        zero_Crossings = crossing(max_Dia_Line,[],threshold);
        threshold = threshold-0.0001;
        Sz = length(zero_Crossings);
        if(Sz>=4 && Sz<=8 && (zero_Crossings(end) - zero_Crossings(1))>2*mmSamples)
            I = find(zero_Crossings > mean([zero_Crossings(1), zero_Crossings(end)]), 1, 'first');
            zero_Crossings = [zero_Crossings(1) zero_Crossings(I)];
            break;
        end
    end
    max_Dia = zero_Crossings(2) - zero_Crossings(1);
    %Try determining thickness from near wall and far wall
    near_Wall_Short_Region = max_Dia_Line(near_Wall_Peak_Loc-2*round(mmSamples): near_Wall_Peak_Loc + 2*round(mmSamples));
    far_Wall_Short_Region = max_Dia_Line(far_Wall_Peak_Loc-2*round(mmSamples): far_Wall_Peak_Loc + 2*round(mmSamples));
    
    %Try to determine two peaks on near wall
    threshold_N = 0.5;
    Sn = 0;
    Pn = [0 0];
    while(Sn(1)~=2 && threshold_N>0.01)
        Pn = peakdet(near_Wall_Short_Region,threshold_N);
        threshold_N = threshold_N-0.01;
        Sn = size(Pn);
    end
    thickness = [0 0];
    if(Sn(1) ==2)
        thickness(1) = Pn(2,1) - Pn(1,1);
    end
    %Try to determine two peaks on far wall
    threshold_P = 0.5;
    Sf = 0;
    Pf = [0 0];
    while(Sf(1)~=2 && threshold_P>0.01)
        Pf = peakdet(far_Wall_Short_Region,threshold_P);
        threshold_P = threshold_P-0.01;
        Sf = size(Pf);
    end
    if(Sf(1) ==2)
        thickness(2) = Pf(2,1) - Pf(1,1);
    end
    [~, I] = max([threshold_N, threshold_P]);
    thickness = thickness(I);
end

function track_Vertical_Diameter_Callback(varargin)
    diameter_Array = zeros(size(pressure_Levels));
    thickness_Array = zeros(size(pressure_Levels));
    
    for i = 1:length(pressure_Levels)
        first_Image = getRCVFullRFFrame(i, 2,1);
        if(sum(sum(first_Image)) == 0)
            first_Image = getRCVFullRFFrame(i, 1,1);
        end
        pData = measurement.PData;
        Origin = pData.Origin;
        X_Int = pData.pdeltaX;
        Z_Int = pData.pdeltaZ;
        interpolation_Factor = 3;
        interpolated_Image = interp2(first_Image,interpolation_Factor);
        central_Line_Loc = 1 + 2^interpolation_Factor *round((Image_Rect_Coordinates.x1- Origin(1))/X_Int);
        mm_Samples = round((2^interpolation_Factor)/(waveLength*Z_Int));
        [diameter_Array(i), thickness_Array(i)]= get_Vertical_Dia(interpolated_Image, central_Line_Loc, mm_Samples);
        diameter_Array(i) = diameter_Array(i)*0.5*waveLength*Z_Int/(2^interpolation_Factor);
        thickness_Array(i) = thickness_Array(i)*0.5*waveLength*Z_Int/(2^interpolation_Factor);
    end
    
    %%%Calculate diameter
    axes(image_Zoom_Frame_Axes_Handle);
    cla;
    temp_Pressure_List = pressure_Levels;
    if(get(merge_Same_Pressures_Check_Box,'value') ==1)
        temp_Pressure_List = unique(pressure_Levels,'First');
    end
    temp_Diameter_Arr = zeros(1, length(temp_Pressure_List));
    temp_Thickness_Arr = 0.46*ones(1, length(temp_Pressure_List));
    for i = 1:length(temp_Pressure_List)
        if(get(merge_Same_Pressures_Check_Box,'value') ==1)
            temp_Diameter_Arr(i)  = mean(diameter_Array(find(pressure_Levels == temp_Pressure_List(i))));
            temp_Thickness_Arr(i) = mean(thickness_Array(find(pressure_Levels == temp_Pressure_List(i))));
        else
            temp_Diameter_Arr(i)  = diameter_Array(i);
            temp_Thickness_Arr(i) = thickness_Array(i);
        end
    end
    diameter_Array = temp_Diameter_Arr
    thickness_Array = temp_Thickness_Arr;
    
    if(get(merge_Same_Pressures_Check_Box,'value') ==1)
        P = [unique(pressure_Levels)]*133.33
    else
        P = (pressure_Levels)*133.33
    end
    D = diameter_Array*10^-3 
    circumference_Arr =2*pi*[diameter_Array/2]*10^-3
    t =median(thickness_Array)*10^-3
    hoop_Stress_Arr = P.*D./(2*t)
    
    elastic_Modulus = median(diff(hoop_Stress_Arr)./(diff(circumference_Arr)./circumference_Arr(1:end-1)))
    
    axes(image_Zoom_Frame_Axes_Handle);
    view([0, 90]);
    cla;
    plot(temp_Pressure_List, diameter_Array, '-o');
    xlabel('Pressure');
    ylabel('Diameter (mm)');
    grid on;
    legend off;
    
    
    axes(analysis_Axes_Handle)
    cla;
    plot(temp_Pressure_List, thickness_Array, '-o');
    xlabel('Pressure (mmHg)');
    ylabel('Thickness (mm)');
    title('');
    grid on;
    legend off;
    
    save('diameter_Data','pressure_Levels', 'diameter_Array');
end

function [density, D0_mm] = Cuff_Calibrate(Pd_mmHg, Ps_mmHg, Dd_mm, Ds_mm, wd_Hz, ws_Hz, t_mm)
Pd = Pd_mmHg*133.3;
Ps = Ps_mmHg*133.3;
Dd = Dd_mm*10^-3;
Ds = Ds_mm*10^-3;
wd = 2*pi*wd_Hz;
ws = 2*pi*ws_Hz;
delD = Ds-Dd;
t = t_mm*10^-3;

density =(Ps-(ws^2 *Pd)/(wd^2))*(4/(ws^2*t*delD));
D0 = Dd - (Pd)/((wd^2*Ps)/(ws^2*delD)- Pd/(delD));
D0_mm = D0/10^-3;
end

function [pressure] = calculate_Pressure(wP_Hz, density, t_mm, D0_mm, DP_mm)
D0 = D0_mm*10^-3;
DP = DP_mm*10^-3;
wP = 2*pi*wP_Hz;
delD = DP-D0;
t = t_mm*10^-3;

pressure =((wP.^2).*density.*t.*delD)/4;
pressure = pressure/133.3;
end

function calibration_Callback(varargin)
    Pd = str2num(get(Pd_Text,'string'));
    Ps = str2num(get(Ps_Text,'string'));
    temp_Pressure_List = pressure_Levels;
    if(get(merge_Same_Pressures_Check_Box,'value') ==1)
        temp_Pressure_List = unique(pressure_Levels,'First');
    end
    wd = freq_Peaks(find(temp_Pressure_List ==Pd, 1, 'first'));
    wd = wd(1,1);
    ws = freq_Peaks(find(temp_Pressure_List ==Ps, 1, 'first'));
    ws = ws(1,1);
    Dd = diameter_Array(find(temp_Pressure_List ==Pd, 1, 'first'));
    Ds = diameter_Array(find(temp_Pressure_List ==Ps, 1, 'first'));
    thickness = median(thickness_Array);
    [density, D0] = Cuff_Calibrate(Pd, Ps, Dd, Ds, wd, ws, thickness);
    set(tube_Density_Value,'String', num2str(density));
    set(D0_Value,'String', num2str(D0));
end

function pressure_Calculation_Callback(varargin)
    density = str2num(get(tube_Density_Value,'String'));
    D0 = str2num(get(D0_Value,'String'));
    
    calculated_Pressures = calculate_Pressure((freq_Peaks(:,1))', density, median(thickness_Array), D0, diameter_Array);
    axes(analysis_Axes_Handle)
    cla;
    temp_Pressure_List = pressure_Levels;
    if(get(merge_Same_Pressures_Check_Box,'value') ==1)
        temp_Pressure_List = unique(pressure_Levels,'First');
    end
    plot(temp_Pressure_List, calculated_Pressures, '-o');
    xlabel('Set Pressures (mmHg)');
    ylabel('Calculated Pressures (mmHG)');
end

function save_Analysis_Callback(varargin)
    analysis_Data.recovery_Arr = recovery_Arr;
    analysis_Data.merged_Pressures_Check = get(merge_Same_Pressures_Check_Box,'value');
    save(current_File_Path,'analysis_Data','-append');
end

function displacement_Parameter_View_Changed(varargin)
    if(isempty(RF_Shift_Arr))
        return;
    end
    cumulative_Arr = zeros(size(RF_Shift_Arr));
    if(cardiac_Cycle_Mode ==0)
        for i = 1:length(voltage_Levels*time_List)
            for j = 1:length(pressure_Levels)
                if(track_WRT_First_Frame ==1)
                    cumulative_Arr(:,i,j) = RF_Shift_Arr(:,i,j);
                else
                    cumulative_Arr(:,i,j) = cumsum(RF_Shift_Arr(:,i,j));
                end
            end
        end
    end
    
    axes(shift_Display_Axes);
    if(get(recovery_Plot_But, 'Value') ==1)
        if(cardiac_Cycle_Mode ==0)
            recovery_Arr = zeros(length(cumulative_Arr(:,:,1)),length(pressure_Levels));
            plot_Colors = rand(length(pressure_Levels),3);
            axes(shift_Display_Axes);
            cla;
            hold on;
            for i = 1:length(pressure_Levels)
                recovery_Arr(:, i) = (squeeze(cumulative_Arr(:,:,i)));
                plot(timing_List_in_us([1, 3:num_of_Frames_Per_Push_Cycle]), recovery_Arr(:,i), 'color',plot_Colors(i,:));
            end
            set_Axis_Labels
        else
            
            cla;
            hold on;
            %plot(cardiac_Cycle_Measurement.ping_Time_Stamps, RF_Shift_Arr);
            D = find_Tube_Diameter(0)*(waveLength);
            if(track_WRT_First_Frame ==0)
              cumulative_Arr  = cumsum(RF_Shift_Arr);
            else
                cumulative_Arr  = RF_Shift_Arr;
            end
            plot(D+cumulative_Arr);
            xlabel('Sample No.');
            ylabel('Diameter (mm)');
            text(1, D+max(cumulative_Arr), ...
                strvcat(['Pings/sec =', num2str(cardiac_Cycle_Measurement.ping_Rate)], ...
                ['Duration of Measurement = ',num2str(cardiac_Cycle_Measurement.Duration), ' ms'], ...
                ['No. of frames per push = ', num2str(cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push)]));
            Fstop = 50;
            Fpass = 100;
            Astop = 5;
            Apass = 0.5;
            Fs = 1/(150*10^-6);
            ds = designfilt('highpassiir','StopbandFrequency',Fstop ,...
              'PassbandFrequency',Fpass,'StopbandAttenuation',Astop, ...
              'PassbandRipple',Apass,'SampleRate',Fs,'DesignMethod','butter');
            if(frame_Num == cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push*cardiac_Cycle_Measurement.total_No_of_Pings)
                waveform_Sampling_Rate = 1/(median(diff(cardiac_Cycle_Measurement.ping_Time_Stamps))*10^-6);
                nFFT = 2048;
                cumulative_Arr_DC_Off = zeros(size(cumulative_Arr));
                cumulative_Arr_DC_Off_First_Points_Off = zeros(length(cumulative_Arr)-cardiac_Cycle_Measurement.total_No_of_Pings,1);
                reference_Dia_Points = zeros(cardiac_Cycle_Measurement.total_No_of_Pings,2);
                
                for s=1:cardiac_Cycle_Measurement.total_No_of_Pings
                    RF_Sub_Wave = cumulative_Arr((s-1)*cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push+1:s*cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push);
                    reference_Dia_Points(s,:) = [(s-1)*cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push+1 RF_Sub_Wave(1)];
                    RF_Sub_Wave = RF_Sub_Wave-mean(RF_Sub_Wave);
                    pow_Fit = fit([2:length(RF_Sub_Wave)]',RF_Sub_Wave(2:length(RF_Sub_Wave)),'power1');
                    RF_Sub_Wave = RF_Sub_Wave - (pow_Fit.a.*([1:length(RF_Sub_Wave)].^pow_Fit.b)');
                    cumulative_Arr_DC_Off((s-1)*cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push+1:s*cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push) = RF_Sub_Wave;
                    cumulative_Arr_DC_Off_First_Points_Off((s-1)*(cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push-1)+1:s*(cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push-1)) = RF_Sub_Wave(2:end)-mean(RF_Sub_Wave(2:end));
                end
%                 cumulative_Arr_DC_Off = filter(ds, cumulative_Arr);
                plot(reference_Dia_Points(:,1), D+reference_Dia_Points(:,2),'--or');
                axes(analysis_Axes_Handle);
                cla;
                
                [S, f] = spectrogram(cumulative_Arr_DC_Off_First_Points_Off,cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push-1, 0,nFFT, waveform_Sampling_Rate);
                S = abs(S);
                N1 = find(f>200,1,'first');
                N2 = find(f<400,1,'last');
                imagesc([1:cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push],f(N1:N2), S(N1:N2,:));
                title('Spectrogram of the cardiac cycle push');
                ylabel('Frequency (Hz)')
                xlabel('Push number');
                axes(image_Zoom_Frame_Axes_Handle);
                view([90 90]);
                cla;
                plot(f(N1:N2), S(N1:N2,:));
                fft_Peak_Locs = zeros(cardiac_Cycle_Measurement.total_No_of_Pings,2);
                for i =1:cardiac_Cycle_Measurement.total_No_of_Pings
                    P=[];
                    fft_Sig = S(N1:N2,i)/max(abs(S(N1:N2,i)));
                    Sz=0;
                    threshold=0.9;
                    while(Sz<2)
                        P = peakdet(fft_Sig,threshold);
                        Sz = size(P);
                        Sz = Sz(1);
                        threshold =threshold-0.01;
                        if(threshold<0.1)
                            [Pk I] = max(fft_Sig);
                            P = [I Pk];
                            break;
                        end
                    end
                    [~, MI] = max(P(:,1));
                    fft_Peak_Locs(i,1) = P(MI,1)+N1-1;
                    fft_Peak_Locs(i,2) = S(P(MI,1)+N1-1,i);
                end
                hold on;
                scatter(f(fft_Peak_Locs(:,1)), fft_Peak_Locs(:,2), ' ok');
                text(mean([f(N1),f(N2)]), fft_Peak_Locs(1,2)/2, strvcat(['median =', num2str(median(f(fft_Peak_Locs(:,1))))], [' std =', num2str(std(f(fft_Peak_Locs(:,1))))]));
                figure
%                 RD_Temp = reference_Dia_Points(:,2)-mean(reference_Dia_Points(:,2));
%                 RD_Temp = RD_Temp/max(abs(RD_Temp));
                subplot(3,2,1);
                plot(D+cumulative_Arr);
                xlabel('Sample No.');
                ylabel('Diameter (mm)');
                hold on;
                plot(reference_Dia_Points(:,1), D+reference_Dia_Points(:,2),'--or');
                text(1, D+max(cumulative_Arr), ...
                strvcat(['Pings/sec =', num2str(cardiac_Cycle_Measurement.ping_Rate)], ...
                ['Duration of Measurement = ',num2str(cardiac_Cycle_Measurement.Duration), ' ms'], ...
                ['No. of frames per push = ', num2str(cardiac_Cycle_Measurement.no_of_Frames_Per_Cardiac_Push)]));
            
                subplot(3,2,3);
                plot(cardiac_Cycle_Measurement.ping_Pressure_List,'--ob');
                xlabel('push Number')
                ylabel('Absolute Measured Pressure (mmHg)')
                
                subplot(3,2,5);
                plot(f(fft_Peak_Locs(:,1)),'--ok');
                xlabel('push Number')
                ylabel('Hoop Frequency Peak (Hz)')
                
                subplot(3,2,2);
                plot(cardiac_Cycle_Measurement.ping_Pressure_List,D+reference_Dia_Points(:,2)./(10*waveLength),'--ob');
                xlabel('Pressure (mmHg)');
                ylabel('Diameter (mm)');
                legend({'PD Relation'});
                
                Dia_in_m = 10^-3*(D+reference_Dia_Points(:,2)./(10*waveLength));
                P_in_Pa = cardiac_Cycle_Measurement.ping_Pressure_List*133.33;
                latex_Thickness = (0.46*10^-3);
                rubber_Thickness = 0.33*10^-3;
                soft_Rubber_Thickness = 0.15*10^-3;
                dialysis_Tube_Thickness = 0.07*10^-3;
                T = rubber_Thickness;
                rubber_Density = 1003;
                soft_Rubber_Density = 1471;
                latex_Density = 1150;
                dialysis_Tube_Density = 3100;
                density = rubber_Density;
                scaling_Factor_For_Latex_In_Water = 1.04e+05;
                scaling_Factor_For_Rungroj = 1.533e+05; %using rubber thickness and density
                scaling_Factor_For_Ashish = 1.022e+05;
                fixed_Scaling_Factor_Per_m_Sqr = scaling_Factor_For_Ashish;
                calculated_Pressure_List_No_Fluid = (2*pi*f(fft_Peak_Locs(:,1))).^2*T*(density).*Dia_in_m/(4*133.33);
                calculated_Pressure_List = (2*pi*f(fft_Peak_Locs(:,1))).^2*T*(density).*Dia_in_m.*(fixed_Scaling_Factor_Per_m_Sqr*Dia_in_m.^2)/(4*133.33);
                valid_Indices = find(cardiac_Cycle_Measurement.ping_Pressure_List>20);
                pressure_Scaling_Factor = cardiac_Cycle_Measurement.ping_Pressure_List(valid_Indices)./calculated_Pressure_List_No_Fluid(valid_Indices);
                
                subplot(3,2,4);
                plot(cardiac_Cycle_Measurement.ping_Pressure_List, '-ob');
                hold on;
                plot(calculated_Pressure_List, '-or');
                median_Error_Percent = 100*median(abs(calculated_Pressure_List(valid_Indices) -cardiac_Cycle_Measurement.ping_Pressure_List(valid_Indices))./cardiac_Cycle_Measurement.ping_Pressure_List(valid_Indices));
                text(2,cardiac_Cycle_Measurement.ping_Pressure_List(2)+20, ['Median % Error = ' num2str(median_Error_Percent)]);
                text(2,cardiac_Cycle_Measurement.ping_Pressure_List(2)+10,  ['Applied Scaling Factor/m^2 =' num2str(fixed_Scaling_Factor_Per_m_Sqr)]);
                xlabel('Sample No.');
                ylabel('Pressure (mmHg)');
                
                
                subplot(3,2,6);
                format long
                [Dia_in_m(valid_Indices), pressure_Scaling_Factor]
                plot((Dia_in_m(valid_Indices)*10^3).^2, pressure_Scaling_Factor, '-ob');
                ideal_Scaling_Factor_Per_m_Sqr = mean(pressure_Scaling_Factor)/mean((Dia_in_m(valid_Indices)).^2)
                text((Dia_in_m(valid_Indices(1))*10^3).^2,max(pressure_Scaling_Factor), ['Ideal Scaling Factor/m^2 = ' num2str(ideal_Scaling_Factor_Per_m_Sqr)]);
                xlabel('Diameter^2 (mm^2)');
                ylabel('Required scaling factor');
                
                subplot(3,2,4);
                calculated_Pressure_With_Ideal_Scaling_Factor = (2*pi*f(fft_Peak_Locs(:,1))).^2*T*(density).*Dia_in_m.*(ideal_Scaling_Factor_Per_m_Sqr*Dia_in_m.^2)/(4*133.33);
                plot(calculated_Pressure_With_Ideal_Scaling_Factor, '-og');
                legend({'Measured Pressure', 'Calculated Pressure (Applied Scaling)', 'Calculated Pressure (Ideal Scaling)'});
                hoop_Stress = (Dia_in_m.*cardiac_Cycle_Measurement.ping_Pressure_List*133.33)/(2*T);
                circumference = pi*Dia_in_m;
                
                p = polyfit(hoop_Stress(valid_Indices),circumference(valid_Indices),1);
                C0 = polyval(p,0);
                D0 = C0/(pi)
                [~,max_Pressure_Index] = max(cardiac_Cycle_Measurement.ping_Pressure_List);
                max_Hoop_Stress = hoop_Stress(max_Pressure_Index);
                max_Dia = Dia_in_m(max_Pressure_Index);
                E = max_Hoop_Stress/((max_Dia-D0)/D0)
                subplot(3,2,2);
                hold on;
                plot(calculated_Pressure_List,D+reference_Dia_Points(:,2)./(10*waveLength),'--or');
                legend({'Across Measured Pressure', 'Across Calculated Pressure'});
                text(cardiac_Cycle_Measurement.ping_Pressure_List(end),10^3*Dia_in_m(1), ['Elastic Modulus = ', num2str(E), ' Pa']);
                
                figure
                plot(cumulative_Arr_DC_Off);
            end
        end
    end
    
    if(get(K_Plot_But, 'Value') ==1)
        S = size(cumulative_Arr);
        
        if(S(1)>2 && K_Plot_Tracking_Frame_Num ==0)
            K_Plot_Tracking_Frame_Num = inputdlg(strvcat(['There are total ', num2str(S(1)), ' tracking frames.'], 'Please enter the frame no. to track:                    ', ' '),'Tracking Frame number',1,{'2'});
            K_Plot_Tracking_Frame_Num = str2num(K_Plot_Tracking_Frame_Num{1});
        else
            K_Plot_Tracking_Frame_Num = 2;
        end
        axes(shift_Display_Axes);
        cla;
        hold on;
        axes(analysis_Axes_Handle);
        cla
        hold on;
        for i = 1:length(pressure_Levels)
            axes(shift_Display_Axes);
            plot_Colors = rand(1,3);
            plot(((voltage_Levels.^2) * time_List*10^-6), cumulative_Arr(K_Plot_Tracking_Frame_Num,:,i), '-o', 'color',plot_Colors, 'LineWidth',2);
            axes(analysis_Axes_Handle);
            plot(((voltage_Levels.^2) * time_List*10^-6),maxCorr_Arr(K_Plot_Tracking_Frame_Num,:,i),'-o', 'color',plot_Colors, 'LineWidth',2);
        end
        axes(shift_Display_Axes);
        if(measurement.sweepMode ==1)
            text(mean(xlim), max(ylim)-diff(ylim)/10,strvcat(['Voltage Sweep Mode'],['Pulse duration = ', num2str(time_List), ' \mus']));
        else
            text(mean(xlim), max(ylim)-diff(ylim)/10,strvcat(['Time Sweep Mode'], ['Voltage = ',num2str(voltage_Levels), ' V']));
        end
        legend(get(pressureList,'String'), 'Location','southwest');
        for i = 1:length(pressure_Levels)
            valid_Indices = find(maxCorr_Arr(K_Plot_Tracking_Frame_Num,:,i)>0.95);
            if(~isempty(valid_Indices))
                axes(shift_Display_Axes);
                X_Indices = ((voltage_Levels.^2) * time_List*10^-6);
                plot(X_Indices(valid_Indices), cumulative_Arr(K_Plot_Tracking_Frame_Num,valid_Indices,i), ' x', 'color','k', 'LineWidth',2);
            end
        end
        axes(analysis_Axes_Handle);
        legend(get(pressureList,'String'), 'Location','southwest');
        title('Trashogram of K Plot');
        xlabel('Voltage^2\timesPulse duration');
        ylabel('Correlation Value');
    end
    
end

function PWV_Data_Acq_Callback(varargin)
    no_of_Snapshots = 2000;
    evalin('base', ['no_of_Snapshots= ', num2str(no_of_Snapshots),';']);
    evalin('base', 'PWV_Interframe_Time_us = 1300;');
    evalin('base', 'PWV_Imaging_Voltage = 50;');
    evalin('base','PWV_Data_Acq');
    S = evalin('base', 'size(IQData{1})');
    S(1) = 2*S(1);
    S(3) = S(4);
    S = S(1:3);
    RFData = zeros(S);
    disp('Converting IQ to RF ...')
    for i =1:no_of_Snapshots
        RFData(:,:,i) = IQtoRF(evalin('base', ['IQData{1}(:,:,',num2str(i),')']));
        drawnow
    end
    disp('RF_Conversion Done.')
    
    PWV_Measurement.interframe_Time = evalin('base','PWV_Interframe_Time_us');
    PWV_Measurement.no_Of_Frames =  evalin('base', 'no_of_Snapshots');
    PWV_Measurement.RFData =  RFData;
    PWV_Measurement.PData = evalin('base','PData');
    PWV_Measurement.frame_Pressure_List = evalin('base','ping_Pressure_List');
    PWV_Measurement.speed_Of_Sound = speed_Of_Sound;
    PWV_Measurement.waveLength =  1000*speed_Of_Sound/transducer_Frequency_in_Hz; 
    evalin('base','clear RcvData');
end

function save_PWV_Data_Callback(varargin)
    i=0;
    [FileName,PathName] = uiputfile('Last_Measurement.PWV','Save PWV Measurement File');
    if(FileName == 0)
        disp('file saving cancelled');
        return
    end

    disp('Saving PWV mmt file...');
    save([PathName, FileName],'PWV_Measurement', '-v7.3');
    disp('File is saved now');
end

function load_PWV_Data_Callback(varargin)
    [FileName,PathName] = uigetfile('*.mat','Select a recorded data file');
    if(FileName == 0)
        disp('Invalid file selction');
        return
    end
    file_Path = [PathName, FileName];
    evalin('base', ['load(''',file_Path,''',''-mat'')']);
    current_File_Path = file_Path;
    [pathstr,name,ext] = fileparts(current_File_Path);
    if(strcmpi(ext,'.PWV')==1 || strcmpi(ext,'.mat')==1 )
        disp('Loading PWV measurement data... please wait.');
        PWV_Measurement = evalin('base','PWV_Measurement');
        disp('PWV measurement data is loaded');
    end
end

function analyze_PWV_Data_Callback(varargin)
    H0 = figure
    imagesc(PWV_Measurement.RFData(:,:,1));
    text(1,1,strvcat({'Please click on four points.', 'Point 1: A bright point on left end of tube', ...
        'Point 2: A bright point on right end of tube', 'Point 3: Leading edge of the front wall',...
        'Point 4: Leading edge of the back wall', 'Complete selection by double click'}));
    [x y] = getpts;
    element1 = round(x(1));
    element2 = round(x(2));
    D0 = (y(4) - y(3))*PWV_Measurement.PData.pdeltaZ*PWV_Measurement.waveLength;
    gap_in_mm = PWV_Measurement.waveLength*(element2-element1)*PWV_Measurement.PData.pdeltaX;
    line11 = squeeze(PWV_Measurement.RFData(:,element1-1,:));
    line12 = squeeze(PWV_Measurement.RFData(:,element1,:));
    line13 = squeeze(PWV_Measurement.RFData(:,element1+1,:));

    line1 = (line11+line12+line13)/3;

    line21 = squeeze(PWV_Measurement.RFData(:,element2-1,:));
    line22 = squeeze(PWV_Measurement.RFData(:,element2,:));
    line23 = squeeze(PWV_Measurement.RFData(:,element2+1,:));

    line2 = (line21+line22+line23)/3;

    close(H0)
    size(line1)
    L = length(line1(:,1));
    line1_High_Resolution_First = interp1((0:L-1),double(line1(:,1)), (0:0.001:L-1),'spline');
    H1 = figure;
    plot(line1_High_Resolution_First);
    title('Left end RF tracking')
    text(1,1,strvcat({'Select proximal and distal wall with two single clicks',...
        'Finish selection with a double click'}));

    [x y] = getpts;
    wall1_Pos = round(x(1));
    wall2_Pos = round(x(2));
    region1 = wall1_Pos-50000:wall1_Pos+50000;
    region2 = wall2_Pos-50000:wall2_Pos+50000;
    H2 = figure
    displacements_line1 = zeros(PWV_Measurement.no_Of_Frames,1);
    for i = 1: PWV_Measurement.no_Of_Frames-1
        line1_High_Resolution_First = interp1((0:L-1),double(line1(:,i)), (0:0.001:L-1),'spline');
        line1_High_Resolution = interp1((0:L-1),double(line1(:,i+1)), (0:0.001:L-1),'spline');

        wall2_Shift = finddelay(line1_High_Resolution(region2), line1_High_Resolution_First(region2));
        wall1_Shift = finddelay(line1_High_Resolution(region1), line1_High_Resolution_First(region1));
        displacements_line1(i) = wall2_Shift - wall1_Shift;

        region1 = region1 - wall1_Shift;
        region2 = region2 - wall2_Shift;

        if(mod(i,10) ==0)
            subplot(3,2,1)
            plot(line1_High_Resolution(region1));
            subplot(3,2,3)
            plot(line1_High_Resolution(region2));
            subplot(3,2,5);
            plot(cumsum(displacements_line1));
            drawnow
        end
    end

    line2_High_Resolution_First = interp1((0:L-1),double(line2(:,1)), (0:0.001:L-1),'spline');
    figure(H1)
    plot(line2_High_Resolution_First,'r');
    title('Right end RF tracking')
    text(1,1,strvcat({'Select proximal and distal wall with two single clicks',...
        'Finish selection with a double click'}));
    [x y] = getpts;
    close (H1);
    wall1_Pos = round(x(1));
    wall2_Pos = round(x(2));
    region1 = wall1_Pos-50000:wall1_Pos+50000;
    region2 = wall2_Pos-50000:wall2_Pos+50000;

    displacements_line2 = zeros(PWV_Measurement.no_Of_Frames,1);
    figure(H2);
    for i = 1: PWV_Measurement.no_Of_Frames-1
        line2_High_Resolution_First = interp1((0:L-1),double(line2(:,i)), (0:0.001:L-1),'spline');
        line2_High_Resolution = interp1((0:L-1),double(line2(:,i+1)), (0:0.001:L-1),'spline');

        wall2_Shift = finddelay(line2_High_Resolution(region2), line2_High_Resolution_First(region2));
        wall1_Shift = finddelay(line2_High_Resolution(region1), line2_High_Resolution_First(region1));
        displacements_line2(i) = wall2_Shift - wall1_Shift;

        region1 = region1 - wall1_Shift;
        region2 = region2 - wall2_Shift;

        if(mod(i,10) ==0)
            subplot(3,2,2)
            plot(line2_High_Resolution(region1),'r');
            subplot(3,2,4)
            plot(line2_High_Resolution(region2),'r');
            subplot(3,2,6);
            plot(cumsum(displacements_line2),'r');
            drawnow
        end
    end

    D = D0+ cumsum(displacements_line1)*PWV_Measurement.PData.pdeltaZ*PWV_Measurement.waveLength*(0.001);
    D = D/2;

    G = sgolayfilt(2,11);
    double_Derivative_Diplacement_Line1 = conv(displacements_line1,G(:,2).','same'); %filter(smooth_diff(11),1,displacements_line1);%
    L = length(displacements_line1);
    first_Derivative_Diplacement_Line1 = interp1((0:L-1),displacements_line1, (0:0.001:L-1),'spline');
    diameter_line1 = D0+ cumsum(displacements_line1)*PWV_Measurement.PData.pdeltaZ*PWV_Measurement.waveLength*(0.001);
    diameter_line1 = diameter_line1/2;

    L = length(line1(:,1));
    line2_High_Resolution_First = interp1((0:L-1),double(line2(:,1)), (0:0.001:L-1),'spline');

    double_Derivative_Diplacement_Line2 = conv(displacements_line2,G(:,2).','same'); %filter(smooth_diff(11),1,displacements_line2);%
    L = length(displacements_line2);
    first_Derivative_Diplacement_Line2 = interp1((0:L-1),displacements_line2, (0:0.001:L-1),'spline');
    diameter_line2 = D0+ cumsum(displacements_line2)*PWV_Measurement.PData.pdeltaZ*PWV_Measurement.waveLength*(0.001);
    diameter_line2 = diameter_line2/2;

    diameter_line1 = interp1((0:L-1),diameter_line1, (0:0.001:L-1),'spline');
    diameter_line2 = interp1((0:L-1),diameter_line2, (0:0.001:L-1),'spline');
    L = length(D);
    D = interp1((0:L-1),D, (0:0.001:L-1),'spline');

    L = length(double_Derivative_Diplacement_Line1);
    double_Derivative_Diplacement_Line1_Interp = interp1((0:L-1),double_Derivative_Diplacement_Line1, (0:0.001:L-1),'spline');
    double_Derivative_Diplacement_Line2_Interp = interp1((0:L-1),double_Derivative_Diplacement_Line2, (0:0.001:L-1),'spline');


    time_Resolution_us = PWV_Measurement.interframe_Time/1000; %1000 times interpolated

    dn1 = diameter_line1-mean(diameter_line1);
    dn1 = dn1/max(abs(dn1));
    dn2 = diameter_line2-mean(diameter_line2);
    dn2 = dn2/max(abs(dn2));
    [P1,V1] = peakdet(dn1,0.1);
    [P2,V2] = peakdet(dn2,0.1);

    V1 = V1(:,1);
    d = 0;
    clean_Window_ms = 60;
    clean_Window_Samples = round(clean_Window_ms*1000/time_Resolution_us);
    H3 = figure
    clf;
    subplot(2,1,1)
    plot(diameter_line1,'b');
    hold on;
    plot(diameter_line2,'r');
    xlabel('interpolated samples (1000 times)')
    ylabel('Diameter (mm)')
    subplot(2,1,2)
    plot(double_Derivative_Diplacement_Line1_Interp,'b');
    hold on;
    plot(double_Derivative_Diplacement_Line2_Interp,'r');
    xlabel('interpolated samples (1000 times)')
    ylabel('Double derivative of diameter (mm)')
    D_Min = [];
    D_Max = [];
    PWV = [];
    d = [];
    delP_mmHg = [];
    H4 = figure;

    for i = 1:length(V1)
        if(V1(i) < clean_Window_Samples)
            continue;
        end
        PI = find(P1(:,1)> V1(i), 1, 'first');
        if(isempty(PI))
            break;
        end
        segment1_Line1 = double_Derivative_Diplacement_Line1_Interp([V1(i)-clean_Window_Samples:P1(PI,1)-clean_Window_Samples]);
        segment1_Line2 = double_Derivative_Diplacement_Line2_Interp([V1(i)-clean_Window_Samples:P1(PI,1)-clean_Window_Samples]);
        figure(H4)
        clf;
        plot(segment1_Line1);
        hold on;
        plot(segment1_Line2,'r');
        D_Min(i) =   D(V1(i));
        D_Max(i) =   D(P1(PI,1));
        [~,MI1] = min(segment1_Line1);
        [~, MI2] = min(segment1_Line2);
        d(i) = finddelay(segment1_Line1, segment1_Line2);
        PWV(i) = gap_in_mm./(d(i)*time_Resolution_us*10^-3);
        delP_mmHg(i) = 2*1000*PWV(i).^2.*log(D_Max(i)./D_Min(i))/133.33;
        figure(H3)
        subplot(2,1,1);
        st = strvcat({strcat('sample diff = ' ,num2str(d(i))), strcat('PWV = ', num2str(PWV(i))),...
            strcat('delP = ', num2str(delP_mmHg(i)))});
        text(V1(i), diameter_line1(V1(i)),st); 
        subplot(2,1,2);
        text(V1(i), double_Derivative_Diplacement_Line1_Interp(V1(i)),st); 
    end

    PWV = gap_in_mm./(d*time_Resolution_us*10^-3)
    delP_mmHg = 2*1000*PWV.^2.*log(D_Max./D_Min)/133.33
end

%%
%%%%Hydrophone Measurement Codes
elevational_Test_Running =0;
evalin('base','snapShoptNum = 0;'); 
evalin('base','save_Snapshot=0;');
function elevational_Focus_Mmt_Callback(varargin)
    if(elevational_Test_Running ==0)
        if(get(focussed_Beam_for_Elevational_Test_Check,'value'))
            evalin('base','focusSetSeq');  %Attempt to autofocus.
            msgbox('Click on the image to set the focal point.');
            disp('Waiting for user focus set ...');
            waitForFocusSet();
            evalin('base','voltage_Levels=3');
        else
            evalin('base', 'focal_Length = 0;');
            evalin('base', 'focal_X = 0;')
            evalin('base','voltage_Levels=5');
        end
        assignin('base', 'exit', 0);
        evalin('base','Mcr_GuiHide = 1') %Control panel hide
        evalin('base','Mcr_DisplayHide = 1'); %Display window hide
        
        evalin('base','current_Voltage_Level_Index =1');
        evalin('base', 'viewer_Mode =1');
        elevational_Test_Running =1;
        %Create directory to save images
        %Clear directoy if it already exists
        try
        rmdir('Elevatonal_Measurements','s');
        catch
        end
        try
        mkdir('Elevatonal_Measurements');
        catch
        end
        evalin('base','snapShoptNum = 1;');
        evalin('base','save_Snapshot = 0;');
        set(elevational_Focus_Measurement_Button, 'String', 'Stop Beam Profile Test');
        evalin('base','Hydrophone_Elevational_Focus_Test_Script');
    else
        assignin('base', 'exit', 1);
        elevational_Test_Running =0;
        set(elevational_Focus_Measurement_Button, 'String', 'Start Beam Profile Test');
    end
end

end
% %%
% %%%%Speckle Tracking Mode codes
% speckle_Track_Mode = 0;
% speckle_Track_Mode_Button = uicontrol(mother_Window, 'Style', 'pushbutton', 'String', 'Speckle Tracking Mode On', 'Units','normalized', 'Position', [0.65 0.975 0.1 0.025], 'Callback', @speckle_Track_Mode_On);
% meshPointsListBox = uicontrol(mother_Window,'Style', 'listbox','Units','normalized', 'Position', [0.27,0.67 0.1 0.2], 'visible','off');
% deleteMeshPointButton = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.27,0.64 0.1 0.03], 'string', 'Delete Mesh Point', 'visible','off','Callback', @delMeshPoint);
% trackMeshButton = uicontrol(mother_Window,'Style', 'pushbutton','Units','normalized', 'Position', [0.27,0.61 0.1 0.03], 'string', 'Track Mesh Shift', 'visible','off','Callback', @trackMeshShift);
% meshPointsList = [];
% function speckle_Track_Mode_On(varargin)
%     if(speckle_Track_Mode == 0)
%         speckle_Track_Mode = 1;
%         set(speckle_Track_Mode_Button,'String', 'Speckle Tracking Mode Off');
%         cla(shift_Display_Axes);
%         set(shift_Display_Axes,'visible','off');
%         cla(single_RF_Axes_Handle);
%         set(single_RF_Axes_Handle,'visible','off');
%         set(operation_Mode,'value',2);
% %         set(operation_Mode,'visible','off');
%         set(acquire_Data_Button,'visible','off');
%         set(save_Data_Button,'visible','off');
%         set(show_Ref_Frames_Button,'visible','off');
%         set(bg,'visible','off');
%         set(bg1,'visible','off');
%         set(pressure_List_Label,'visible','off');
%         set(pressure_List_Command,'visible','off');
%         set(voltage_List_Label,'visible','off');
%         set(voltage_List_Command,'visible','off');
%         set(num_Of_Frames_Per_Voltage_Label,'visible','off');
%         set(num_Of_Frames_Per_Voltage,'visible','off');
%         set(num_Push_Pulses_Label,'visible','off');
%         set(num_Push_Pulses_Text,'visible','off'); 
%         set(set_Speed_of_Sound_Label,'visible','off');
%         set(set_Speed_of_Sound_Text,'visible','off');
%         set(show_Live_Images,'visible','off');
%         set(show_Ref_Frames,'visible','off');
%         set(push_On_Check,'visible','off');
%         set(push_Viewer_Voltage_Slider_Label,'visible','off');
%         set(push_Viewer_Voltage_Slider,'visible','off');
%         set(time_Between_Acq_in_Viewer_Mode_Label,'visible','off');
%         set(time_Between_Acq_in_Viewer_Mode_Text,'visible','off');
%         set(longitudinal_Mode_Check,'visible','off');
%         set(flash_Angles_Check,'visible','off');
%         set(track_Both_Sides_Check,'visible','off');
%         set(display_Images_Check,'visible','off');
%         set(track_at_Focus_Check,'visible','off');
%         set(track_Button,'visible','off');
%         set(mother_Window, 'WindowButtonDownFcn', @actOnMouseClicksSpeckleTracking);
%         set(meshPointsListBox,'visible','on');
%         set(deleteMeshPointButton,'visible','on');
%         set(trackMeshButton,'visible','on');
%     else
%         speckle_Track_Mode = 0;
%         set(speckle_Track_Mode_Button,'String', 'Speckle Tracking Mode On');
%         set(shift_Display_Axes,'visible','on');
%         set(single_RF_Axes_Handle,'visible','on');
% %         set(operation_Mode,'visible','on');
%         set(acquire_Data_Button,'visible','on');
%         set(save_Data_Button,'visible','on');
%         set(show_Ref_Frames_Button,'visible','on');
%         set(bg,'visible','on');
%         set(bg1,'visible','on');
%         set(pressure_List_Label,'visible','on');
%         set(pressure_List_Command,'visible','on');
%         set(voltage_List_Label,'visible','on');
%         set(voltage_List_Command,'visible','on');
%         set(num_Of_Frames_Per_Voltage_Label,'visible','on');
%         set(num_Of_Frames_Per_Voltage,'visible','on');
%         set(num_Push_Pulses_Label,'visible','on');
%         set(num_Push_Pulses_Text,'visible','on'); 
%         set(set_Speed_of_Sound_Label,'visible','on');
%         set(set_Speed_of_Sound_Text,'visible','on');
%         set(show_Live_Images,'visible','on');
%         set(show_Ref_Frames,'visible','on');
%         set(push_On_Check,'visible','on');
%         set(push_Viewer_Voltage_Slider_Label,'visible','on');
%         set(push_Viewer_Voltage_Slider,'visible','on');
%         set(time_Between_Acq_in_Viewer_Mode_Label,'visible','on');
%         set(time_Between_Acq_in_Viewer_Mode_Text,'visible','on');
%         set(longitudinal_Mode_Check,'visible','on');
%         set(flash_Angles_Check,'visible','on');
%         set(track_Both_Sides_Check,'visible','on');
%         set(display_Images_Check,'visible','on');
%         set(track_at_Focus_Check,'visible','on');
%         set(track_Button,'visible','on');
%         set(mother_Window, 'WindowButtonDownFcn', @actOnMouseClicks);
%         set(meshPointsListBox,'visible','off');
%         set(deleteMeshPointButton,'visible','off');
%         set(trackMeshButton,'visible','off');
%     end
% end
% 
% function actOnMouseClicksSpeckleTracking(varargin)
%     cursorPoint = get(image_Frame_Axes_Handle, 'CurrentPoint');
%     curX = cursorPoint(1,1);
%     curY = cursorPoint(1,2);
%     xLimits = get(image_Frame_Axes_Handle, 'xlim');
%     yLimits = get(image_Frame_Axes_Handle, 'ylim');
%     
%     if (curX > min(xLimits) && curX < max(xLimits) && curY > min(yLimits) && curY < max(yLimits))
%         R = find_Rect(current_Image_Frame, image_Frame_Axes_Handle, curX, curY, zoom_Level);
%         meshPointsList = [meshPointsList;R.x1 R.x2 R.y1 R.y2];
%         set(meshPointsListBox,'String',num2str(meshPointsList));
%         S = size(meshPointsList);
%         set(meshPointsListBox,'value',S(1));
%         placeSquares
%     end
% end
% 
% function delMeshPoint(varargin)
%     listIndex = get(meshPointsListBox,'value');
%     S = size(meshPointsList);
%     if(listIndex == S(1) && S(1)~=0)
%         set(meshPointsListBox,'value', listIndex-1);
%     elseif(S(1)==0 || listIndex <=0)
%         set(meshPointsListBox,'value',1);
%     end
%     
%     if(S(1)>0)
%         meshPointsList(listIndex,:) = [];
%         set(meshPointsListBox,'String',num2str(meshPointsList));
%     end
%     find_Rect(current_Image_Frame, image_Frame_Axes_Handle, 0, 0, zoom_Level);
%     placeSquares
% end
% 
% function placeSquares()
%     S = size(meshPointsList);
%     for i = 1:S(1)
%         rectangle('Position', [meshPointsList(i,1) meshPointsList(i,3) meshPointsList(i,2)-meshPointsList(i,1) meshPointsList(i,4)-meshPointsList(i,3)],'EdgeColor', [1 1 1])
%     end
%     drawnow
% end
% 
% function trackMeshShift(varargin)
%     full_Image_Frames_Movie = struct('cdata',[],'colormap',[]);
%     movie_Size = 280;%350;
%     for k = 1;%:length(pressure_Levels)
%         set(pressureList,'Value', k);
%         for j = 1;%:length(voltage_Levels)
%             set(voltageList,'Value', j);
%             i_Range = [1 3:num_of_Frames_Per_Push_Cycle];
%             for i = 1:length(i_Range)-1
%                 [xShifts, yShifts] = findShiftforAllRect(i_Range(i), i_Range(i+1));
%                 vector_Starts_X = (meshPointsList(:,2)+meshPointsList(:,1))/2;
%                 vector_Starts_Y = (meshPointsList(:,4)+meshPointsList(:,3))/2;
%                 vector_Length_X = (xShifts-mean(xShifts))';
%                 vector_Length_Y = (yShifts-mean(yShifts))';
% %                 meshPointsList(:,1) = meshPointsList(:,1)+xShifts';
% %                 meshPointsList(:,2) = meshPointsList(:,2)+xShifts';
% %                 meshPointsList(:,3) = meshPointsList(:,3)+yShifts';
% %                 meshPointsList(:,4) = meshPointsList(:,4)+yShifts';
%                 placeSquares
%                 axes(image_Frame_Axes_Handle)
%                 quiver(vector_Starts_X,vector_Starts_Y,vector_Length_X,vector_Length_Y, 'w', 'LineWidth',2);
%                 drawnow;
%                 full_Image_Frames_Movie((k-1)*length(voltage_Levels)*length(i_Range)+(j-1)*length(i_Range)+i) = getframe(image_Frame_Axes_Handle);
%                 full_Image_Frames_Movie((k-1)*length(voltage_Levels)*length(i_Range)+(j-1)*length(i_Range)+i).cdata = full_Image_Frames_Movie((k-1)*length(voltage_Levels)*length(i_Range)+(j-1)*length(i_Range)+i).cdata(1:movie_Size,1:movie_Size,:);
%                 
%             end
%         end
%     end
%     myVideo = VideoWriter('velocity_Vector_Tracking.avi');
%     open(myVideo);
%     writeVideo(myVideo, full_Image_Frames_Movie);
%     close(myVideo);
% end
% 
% function [xShifts, yShifts] = findShiftforAllRect(baseFrameNum, currentFrameNum)
%     baseImage = getImageFrame(3, baseFrameNum, 1);
%     currentImage = getImageFrame(3, currentFrameNum, 1);
%     
%     pData = measurement.PData;
%     Origin = pData.Origin;
%     X_Int = pData.pdeltaX;
%     Z_Int = pData.pdeltaZ;
%     zoom_Interval = 1/50; %50 points per wavelength
%     
%     S = size(meshPointsList);
%     for i = 1:S(1)
%         ROI_Rect = meshPointsList(i,:);
%         Z_SubAxis = round(ROI_Rect(3)/Z_Int):round(ROI_Rect(4)/Z_Int);
%         X_SubAxis = round(ROI_Rect(1)/X_Int):round(ROI_Rect(2)/X_Int);
%         zoomed_Base_Image = baseImage(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int));
%         zoomed_Current_Image = currentImage(round(Z_SubAxis - Origin(3)/Z_Int), round(X_SubAxis - Origin(1)/X_Int));
% 
%         start_Point = Z_SubAxis(1)*Z_Int;    
%         end_Point = Z_SubAxis(end)*Z_Int; 
%         Z_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);
% 
%         start_Point = X_SubAxis(1)*X_Int;
%         end_Point = X_SubAxis(end)*X_Int;
%         X_SubAxis_Zoomed = (start_Point:zoom_Interval:end_Point);
%         [X, Z] = meshgrid(X_SubAxis*X_Int, Z_SubAxis*Z_Int);
%         [Xq, Zq] = meshgrid(X_SubAxis_Zoomed, Z_SubAxis_Zoomed);
%         zoomed_Current_Image = interp2(X, Z, zoomed_Current_Image, Xq, Zq, 'spline');
%         zoomed_Base_Image = interp2(X, Z, zoomed_Base_Image, Xq, Zq, 'spline');
% 
%         axes(image_Zoom_Frame_Axes_Handle);
%         cla;
%         imagesc(X_SubAxis_Zoomed, Z_SubAxis_Zoomed, zoomed_Base_Image)
% 
%         axes(image_Zoom_Frame_Axes_Handle);
%         cla;
%         imagesc(X_SubAxis_Zoomed, Z_SubAxis_Zoomed, zoomed_Current_Image);
% 
%         X = xcorr2(zoomed_Base_Image, zoomed_Current_Image);
%         CorrCenterX = length(X_SubAxis_Zoomed);
%         CorrCenterY = length(Z_SubAxis_Zoomed);
% 
%         [num idx] = max(X(:));
%         [shiftY shiftX] = ind2sub(size(X),idx);
%         xShifts(i) = -(shiftX - CorrCenterX)*zoom_Interval;
%         yShifts(i) = -(shiftY - CorrCenterY)*zoom_Interval;
%     end
%     axes(image_Frame_Axes_Handle);
%     cla;
%     S = size(currentImage);
%     imagesc(Origin(1)+ [0:S(2)-1]*X_Int, Origin(3)+[0:S(1)-1]*Z_Int, non_Linear_Gain_On_Image(currentImage));
% end



