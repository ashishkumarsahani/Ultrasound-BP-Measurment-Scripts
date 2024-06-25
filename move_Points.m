function move_Points
    persistent position_Index;
    persistent position_Multiplier;
    if isempty(position_Index)
        position_Index = 0;
    end
    reset_Phantom = evalin('base', 'reset_Phantom');
    if(reset_Phantom ==1)
        disp('phantom position reset');
        position_Index = 0;
        rng('shuffle');
        position_Multiplier = 1+round(rand*10); %set new random start position index
        evalin('base', 'reset_Phantom = 0;');
        disp(['Position shift set to = ', num2str(position_Multiplier*0.01)]);
    end
    pos_Shift_in_Wavelength = position_Multiplier*position_Index*0.01; %0.1 Wavelength steps
    position_Index = mod(position_Index+1, evalin('base', 'num_of_Frames_Per_Push_Cycle'));
    firstLine_InitialPosition = pos_Shift_in_Wavelength + evalin('base', '20/wavelength_in_mm');
    first_Line_X_Pos = [-20:20];
    S = size(first_Line_X_Pos);
    first_Line_Y_Pos = zeros(1, S(2));
    first_Line_Z_Pos = ones(1, S(2))*firstLine_InitialPosition;
    second_Line_X_Pos = first_Line_X_Pos;
    second_Line_Y_Pos = first_Line_Y_Pos;
    second_Line_Z_Pos = ones(1, S(2))*firstLine_InitialPosition+ evalin('base', '(4)/wavelength_in_mm');
    Media = evalin('base', 'Media');
%     Media = rmfield(Media, 'MP');
    Media.Model = 'PointTargets1';
    %Media.MP = zeros(S(2), 4);
    for i = 1:S(2)%length(first_Line_X_Pos)
        Media.MP(i,1) = first_Line_X_Pos(i);
        Media.MP(i,2) = first_Line_Y_Pos(i);
        Media.MP(i,3) = first_Line_Z_Pos(i);
        Media.MP(i,4) = 0.6;
    end
    
    for i = S(2)+1:2*S(2)%length(first_Line_X_Pos)
        Media.MP(i,1) = second_Line_X_Pos(i - S(2));
        Media.MP(i,2) = second_Line_Y_Pos(i - S(2));
        Media.MP(i,3) = second_Line_Z_Pos(i - S(2));
        Media.MP(i,4) = 0.3;
    end
    
    assignin('base', 'Media', Media);
end