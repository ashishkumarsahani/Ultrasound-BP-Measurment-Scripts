function chanagetoCurrentFrameinImageProcess()
    evalin('base', 'currentFrame = mod(currentFrame, Resource.ImageBuffer(1).numFrames)+1;');
    evalin('base', 'Process(1).Parameters.framenum = currentFrame;');
end