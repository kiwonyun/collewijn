function makeSynData()

%% load test data and plot
load('testdata/raw.mat')
% subplot(3,1,1)
% plot(trials.eye(:,1),trials.eye(:,2),'o',trials.target(:,1),trials.target(:,2),'+')
frequency = sscanf(targetFrequency,'%f');
minTarget = min(trials.target(:,2));
maxTarget = max(trials.target(:,2));
trials.sac_L = zeros(1,9);
trials.sac_R = zeros(1,9);
phaseTweak = -deg2rad(1.337) + pi; % due to small delay in target start...
ampl = (maxTarget - minTarget)/2;
offs = (maxTarget + minTarget) /2;

%% make 0 phase 1 gain plus noise
synPos = offs + ampl * cos(phaseTweak + 2*pi*(frequency/1000)*trials.eye(:,1));
% synPos = synPos + randn(length(synPos),1)*ampl*0.05;
trials.eye(:,2) = synPos;
trials.eye(:,3) = 0;

subplot(3,1,1)
plot(trials.target(:,1),trials.target(:,2),trials.eye(:,1),trials.eye(:,2))

save('testdata/0phase1gain0noise.mat','background','collectedData','direction',...
    'period','sample_rate','targetColor','targetFrequency','targetSize','trials');

%% make 0 phase 0.5 gain 
synPos = offs + ampl/2 * cos(phaseTweak + 2*pi*(frequency/1000)*trials.eye(:,1));
trials.eye(:,2) = synPos;
trials.eye(:,3) = 0;

subplot(3,1,2)
plot(trials.target(:,1),trials.target(:,2),trials.eye(:,1),trials.eye(:,2))

save('testdata/0phase0_5gain.mat','background','collectedData','direction',...
    'period','sample_rate','targetColor','targetFrequency','targetSize','trials');

%% make 5 phase 1 gain
synPos = offs + ampl * cos(deg2rad(5) + phaseTweak + 2*pi*(frequency/1000)*trials.eye(:,1));
trials.eye(:,2) = synPos;
trials.eye(:,3) = 0;

subplot(3,1,2)
plot(trials.target(:,1),trials.target(:,2),trials.eye(:,1),trials.eye(:,2))

save('testdata/5phase1gain.mat','background','collectedData','direction',...
    'period','sample_rate','targetColor','targetFrequency','targetSize','trials');

drawnow
targfit

