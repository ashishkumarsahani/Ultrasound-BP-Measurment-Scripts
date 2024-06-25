sc=5;
%rows=[45:70];
%cols=[80:155];
%rows=[500:700];
%cols=[1000:1300];

per =.2;
threshold = 4;
%filename=uigetfile('*.mat');
%load(filename);
%IQData{1}=IQData{1}/1e8;
%IQData{2}=IQData{2}/1e8;
vw=zeros(4);
AZ=-90;
EL=51;
while 1==1
    for run = 1:size(IQData{1},4)
        figure (11);
        %colormap(gray);
        %Frame = imresize(abs(IQData{1}(1:140,150:350,1,run)),sc);
        Frame = imresize(abs(IQData{1}(:,:,1,run)),sc);
        Frame=(Frame-mean(mean(Frame)))/std(std(Frame));
        %Frame=Frame(:,:)>threshold;
        imagesc (Frame);
        %view ([AZ EL]);
        axis equal tight
        cmap=caxis;
        %colormap(gray);
        title(strcat('Reference image, run:', num2str(run)));
        %waitforbuttonpress;
        pause (per+0.3);
        for i=1:2
            figure (11);
            %Frame = imresize(abs(IQData{2}(1:140,150:350,i,run)),sc);
            Frame = imresize(abs(IQData{2}(:,:,i,run)),sc);
            Frame=(Frame-mean(mean(Frame)))/std(std(Frame));
            %Frame=Frame(:,:)>threshold;
            imagesc(Frame,cmap);
            %view([AZ EL]);
            %colormap(gray);
            title (strcat('Tracking image: ',num2str(i),', run:',num2str(run)));
            axis equal tight
            %waitforbuttonpress;
            pause (per);
        end
    end
end

