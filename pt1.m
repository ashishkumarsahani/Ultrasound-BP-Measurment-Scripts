% Copyright 2001-2013 Verasonics, Inc.  All world-wide rights and remedies under all intellectual property laws and industrial property laws are reserved.  Verasonics Registered U.S. Patent and Trademark Office.
% 
%--------------------------- pt1.m ------------------------------

Media.Model = 'PointTargets1';

% Uncomment for speckle.
% Media.MP = rand(20000,4);
% Media.MP(:,4) = 0.03*Media.MP(:,3) + 0.015;  % Random amplitude 
% Media.MP(:,1) = 128*(Media.MP(:,1)-0.5);
% Media.MP(:,2) = 0;
% Media.MP(:,3) = 200*Media.MP(:,3);
Media.MP = zeros(100, 4);
Media.MP(1,:) = [-45.5,0,30,1.0];
Media.MP(2,:) = [-15.5,0,30,1.0];
Media.MP(3,:) = [15.5,0,30,1.0];
Media.MP(4,:) = [45.5,0,30,1.0];
Media.MP(5,:) = [-15.5,0,60,1.0];
Media.MP(6,:) = [-15.5,0,90,1.0];
Media.MP(7,:) = [-15.5,0,120,1.0];
Media.MP(8,:) = [-15.5,0,150,1.0];
Media.MP(9,:) = [-45.5,0,120,1.0];
Media.MP(10,:) = [15.5,0,120,1.0];
Media.MP(11,:) = [45.5,0,120,1.0];
Media.MP(12,:) = [-10.5,0,69,1.0];
Media.MP(13,:) = [-5.5,0,75,1.0];
Media.MP(14,:) = [0.5,0,78,1.0];
Media.MP(15,:) = [5.5,0,80,1.0];
Media.MP(16,:) = [10.5,0,81,1.0];
Media.MP(17,:) = [-75.5,0,120,1.0];
Media.MP(18,:) = [75.5,0,120,1.0];
Media.MP(19,:) = [-15.5,0,180,1.0];
% Media.MP(20,:) = [17,0,120,1.0];
% Media.MP(21,:) = [19,0,120,1.0];
% 
% Media.MP(:,1) = Media.MP(:,1) + 0.25;

Media.numPoints = size(Media.MP,1);