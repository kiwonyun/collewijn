function view_eye(eye,target)
% view_eye - view the eye movements vs. target movements
close all
% Prepare the new file.
vidObj = VideoWriter('eye.avi');
vidObj.FrameRate = 60;
open(vidObj);

t = eye(1).time;
idx_max = length(t);
target_pos = resample(target(1).pos,length(eye(1).pos),length(target(1).pos));
eye_pos = eye(1).pos;

figure

set(gca,'NextPlot','replacechildren');

for idx = 1:(idx_max-3)
    subplot(2,1,1)
    plot(t,eye_pos,t,target_pos,t(idx),target_pos(idx),'ro')
    subplot(2,1,2)
    plot(eye_pos(idx:(idx+3)),[0 0 0 0],'+',target_pos(idx:idx+3),[0 0 0 0],'o');
    xlim([-10 10])
    currFrame = getframe(gcf);
    writeVideo(vidObj,currFrame);
end

close(vidObj)