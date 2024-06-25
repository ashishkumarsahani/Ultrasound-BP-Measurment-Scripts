function RF_Display_Function(RData)
    axes(evalin('base', 'user_Fig_Handle'));
    hold off;
    plot(RData(:,3));
    hold on;
    plot(RData(:,126),'r');
    ylim([-100 100]);
    drawnow;
end