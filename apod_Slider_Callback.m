function apod_Slider_Callback(varargin)
if evalin('base','exist(''TX'',''var'')')
    TX = evalin('base','TX');
else
    disp('TX object not found in workplace.');
    return
end
c = get(findobj('Tag', 'apod_Slider'),'value')

x = [1:128];
Apod_Gauss_Curve = exp(-((x-64.5).^2)./(2*c^2));
TX(1).Apod = Apod_Gauss_Curve;

assignin('base', 'TX', TX);
end