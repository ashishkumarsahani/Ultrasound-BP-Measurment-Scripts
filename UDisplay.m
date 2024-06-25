function UDisplay(DisplayData)
% External display code goes here.
    axes(evalin('base', 'user_Fig_Handle'));
    hold off;
    S = size(DisplayData);
    X_Int = evalin('base', 'Resource.DisplayWindow(1).pdelta');
    Z_Int = evalin('base', 'Resource.DisplayWindow(1).pdelta');
    Origin = evalin('base', 'PData(1).Origin');
    imagesc(Origin(1)+ [0:S(2)-1]*X_Int, Origin(3)+[0:S(1)-1]*Z_Int, DisplayData);
    hold on;
    line(Origin(1)+[((S(2)*0.5)*X_Int), ((S(2)*0.5)*X_Int)], Origin(3)+ [0*Z_Int, (S(2))*Z_Int], 'LineWidth',3,'Color',[.8 0 0], 'LineStyle','-.');

    readytoFocus = evalin('base', 'getReadytoFocus');
    if(readytoFocus ==1) %Don't show reference frame while focussing
        disp('Auto focussing now ...');
        %max_Val = max(DisplayData(:));
        threshold_min = prctile(DisplayData(:),97);
        [maxloc_row, maxloc_col] = find(DisplayData > threshold_min);
        maxloc_col = median(maxloc_col);
        max_Col_Data = DisplayData(:,round(maxloc_col));
        maxloc_row = find(max_Col_Data>threshold_min,1,'first');
        
        evalin('base', ['focal_Length =', num2str(Origin(3)+(maxloc_row-1)*Z_Int)]);
        evalin('base', ['focal_X =',num2str(Origin(1)+(maxloc_col-1)*X_Int)]);
        evalin('base','TX(2).focus = focal_Length;');
    else
        focal_Row = round((evalin('base','focal_Length')-Origin(3))/Z_Int);
        focal_Column = round((evalin('base','focal_X')-Origin(1))/X_Int);
        scatter(Origin(1)+(focal_Column*X_Int), Origin(3)+Z_Int*(focal_Row), 100, '+', 'MarkerEdgeColor',[0 0 0.7], 'MarkerFaceColor',[0.7 0.7 0], 'LineWidth',2);
        
        save_Snapshot = evalin('base','save_Snapshot');
        if(save_Snapshot ==1)
            text(Origin(1)+(focal_Column*X_Int), Origin(3)+Z_Int*(focal_Row), ['(',num2str(Origin(1)+(focal_Column*X_Int)),' , ',num2str(Origin(3)+Z_Int*(focal_Row)),')'],'Color','white');
            figure_Name = strcat('Elevatonal_Measurements\',num2str(evalin('base','snapShoptNum')),'.jpg');
            F = getframe(evalin('base', 'user_Fig_Handle'));
            Image = frame2im(F);
            imwrite(Image, figure_Name);
            evalin('base','snapShoptNum = snapShoptNum+1;'); 
            evalin('base','save_Snapshot=0');
        end
        
        axes(evalin('base', 'zoomed_Fig_Handle'));
        num_Of_Lines_To_Show = round(S(2)/10);
        imagesc(Origin(1)+ X_Int*(focal_Column-num_Of_Lines_To_Show:focal_Column+num_Of_Lines_To_Show), Origin(3)+Z_Int*(focal_Row-num_Of_Lines_To_Show:focal_Row+num_Of_Lines_To_Show), DisplayData(focal_Row-num_Of_Lines_To_Show:focal_Row+num_Of_Lines_To_Show, focal_Column-num_Of_Lines_To_Show:focal_Column+num_Of_Lines_To_Show));
    end
    drawnow
    evalin('base', 'getReadytoFocus = 0;');
end