% Viewer for 4-D IQ Data Array
open Review.m;
[ImageDepth, ImageWidth, NumPages, NumFrames] = size(IQData{2});
StartDepth = 1+floor(0.01*ImageDepth);
EndDepth = floor(0.2*ImageDepth);
LeftEdge = 1+floor(0*ImageWidth);
RightEdge = floor(1.0*ImageWidth);

scrsz = get(0,'ScreenSize');

while(1)
    for Frame = 1:NumFramesValid

       figure(555);
       % figure positions are designated by [left, bottom, width, height]
       set(gcf,'OuterPosition',[1 scrsz(4)/2 scrsz(3)/3 scrsz(4)/2])
       page = 1;
           subplot(311)
            imagesc(real(IQData{1}(StartDepth:EndDepth,LeftEdge:RightEdge,page, Frame)))
            title(['Real Plot of Reference Frame = ' num2str(Frame) ]); %    Page = ' num2str(page)]);
            subplot(312)
            imagesc(imag(IQData{1}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame)))
            title(['Imaginary Plot of Reference Frame = ' num2str(Frame) ]); %    Page = ' num2str(page)]);
            subplot(313)
            imagesc(abs(IQData{1}(StartDepth:EndDepth,LeftEdge:RightEdge, page, Frame)))
            title(['Absolute Value Plot of Reference Frame = ' num2str(Frame) ]); %    Page = ' num2str(page)]);
            pause(0.1);

        
        figure(777);
%         set(gcf,'OuterPosition',[scrsz(3)/3 scrsz(4)/2 scrsz(3)/3 scrsz(4)/2])
        set(gcf,'OuterPosition',[1 1 scrsz(3) scrsz(4)])
        for page = 1:ne
            subplot(311)
            imagesc(real(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame)))
            title(['Real Plot of Tracking Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
            subplot(312)
            imagesc(imag(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame)))
            title(['Imaginary Plot Tracking of Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
            subplot(313)
            imagesc(abs(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame)))
            title(['Absolute Value Tracking Plot of Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
            pause(0.1);
        end
        
%         figure(999);
%         set(gcf,'OuterPosition',[2*scrsz(3)/3 scrsz(4)/2 scrsz(3)/3 scrsz(4)/2])
%         for page = 1:ne
%             subplot(311)
%             imagesc(real(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame))-real(IQData{1}(StartDepth:EndDepth,LeftEdge:RightEdge,1,Frame)))
%             title(['Real Plot of Difference Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
%             subplot(312)
%             imagesc(imag(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame))-imag(IQData{1}(StartDepth:EndDepth,LeftEdge:RightEdge,1,Frame)))
%             title(['Imaginary Plot Difference of Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
%             subplot(313)
%             imagesc(abs(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame))-abs(IQData{1}(StartDepth:EndDepth,LeftEdge:RightEdge,1,Frame)))
%             title(['Absolute Value Difference Plot of Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
%             pause(0.1);
%         end

        
    end
end
%%
 figure(888);
 page = 1;
 Frame = 1;
             subplot(311)
            imagesc(real(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame)))
            title(['Real Plot of Tracking Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
            subplot(312)
            imagesc(imag(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame)))
            title(['Imaginary Plot of Tracking Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
            subplot(313)
            imagesc(abs(IQData{2}(StartDepth:EndDepth,LeftEdge:RightEdge,page,Frame)))
            title(['Absolute Value Plot of Tracking Frame = ' num2str(Frame) '    Page = ' num2str(page)]);
%% View RcvData
scrsz = get(0,'ScreenSize');
ChanNum = 64;
page = 1;
Frame = 4;
% for Frame = 1:NumFrameStore
    figure(1111);
    set(gcf,'OuterPosition',[2*scrsz(3)/3 scrsz(4)/2 scrsz(3)/3 scrsz(4)/2])
%     imagesc(RcvData{1}(1:1024+1024*(page-1),:,Frame)); colorbar;
        imagesc(RcvData{1}(:,:,Frame)); colorbar;
     title(['Raw Receive Data from Frame ' num2str(Frame)]);
    figure(1212);
    set(gcf,'OuterPosition',[scrsz(3)/3 scrsz(4)/2 scrsz(3)/3 scrsz(4)/2])
    plot(RcvData{1}(1:1024+1024*(page-1),ChanNum,Frame));
    title(['Raw Receive Data from Frame ' num2str(Frame) '     Channel Number ' num2str(ChanNum)]);
    pause(1);
% end


