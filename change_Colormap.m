function change_Colormap()
    figure_Handle = evalin('base', 'Resource.DisplayWindow(1).figureHandle');
    set(figure_Handle, 'Colormap', jet(256));
    set(gca, 'Units', 'normalized', 'Position', [0 0 1 1] );
end