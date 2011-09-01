function view_eye(trial_num)
% view_eye(trial_num) - view the eye movements vs. target movements
% trial_num is an integer that selects which trial to show.
% needs the results from targfit.m

if ~exist('trial_num','var')
    trial_num = 1;
end

[eye, target] = targfit;

% Prepare the new file.
vidObj = VideoWriter('eye.avi'); % FIXME  name with data file name
vidObj.FrameRate = 60;
open(vidObj);

t = eye(trial_num).time;
idx_max = length(t);
target_pos = resample(target(trial_num).pos,length(eye(trial_num).pos),...
    length(target(trial_num).pos));
eye_pos = eye(trial_num).pos;

figure

set(gca,'NextPlot','replacechildren');

for idx = 1:(idx_max-3)
    subplot(2,1,1)
    plot(t,eye_pos,t,target_pos,t(idx),target_pos(idx),'ro',t,eye_pos - target_pos)
    subplot(2,1,2)
    plot(eye_pos(idx:(idx+3)),[0 0 0 0],'+',target_pos(idx:idx+3),[0 0 0 0],'o');
    xlim([-10 10])
    currFrame = getframe(gcf);
    writeVideo(vidObj,currFrame);
end

close(vidObj)