function hide_VSXFig()
h = evalin('base', 'Resource.DisplayWindow(1).figureHandle');
set(h,'Visible','off');
end