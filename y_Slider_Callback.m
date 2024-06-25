function y_Slider_Callback(varargin)
    disp('slider move');
    Media = [];
    if evalin('base','exist(''Media'',''var'')')
        Media = evalin('base','Media')
    else
        disp('Media object not found in workplace.');
        return
    end
    r = 8;
    theta = [0:0.1:2*pi];
    x_Arr = r*cos(theta);
    z_Arr = r*sin(theta);
    z_Arr = z_Arr - get(findobj('Tag', 'y_Slider'),'value');
    for i = 1:length(theta)
        Media.MP(i,:) = [x_Arr(i),0, z_Arr(i),0.5];
    end

    assignin('base', 'Media', Media);
end