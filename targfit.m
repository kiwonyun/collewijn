function [trials,B] = targfit(filename,print_flag)
% eyefit - fit ideal funtion to eye trace data to estimate gain and lag of
% participant eye motion. Eye traces are broken into fast and slow
% components. The fast components are the saccades. Right now saccade tags
% generated by the eyelink are used. We plan to write our own saccade
% identification routines.
% Data is prepared by first converting from .edf to asc using the GUI
% converter from SR Research. Then our script process_all_asc_data is run
% to preprocess and convert the asc data to .mat files.

%% load data
warning off %#ok<WNOFF>
if ~exist('filename','var')
    [filename,pathname] = uigetfile;
    load([pathname filename])
else
    load(filename)
end

if ~exist('print_flag','var')
    print_flag = false;
end

% view trials
numTrials = size(trials,2);
for i=1:numTrials
    
    figure(i)
    numSac_L=size(trials(i).sac_L,1);
    if numSac_L > 0
        a=mean(trials(i).sac_L,1);
        meanDur_L=a(3);
        meanAmp_L=a(8);
        meanVel_L=a(9);
    else
        trials(i).sac_L = [0 0 0 0 0 0 0 0 0];
        meanDur_L=0;
        meanAmp_L=0;
        meanVel_L=0;
    end
    numSac_R=size(trials(i).sac_R,1);
    if numSac_R > 0
        a=mean(trials(i).sac_R,1);
        meanDur_R=a(3);
        meanAmp_R=a(8);
        meanVel_R=a(9);
    else
        trials(i).sac_R = [0 0 0 0 0 0 0 0 0];
        meanDur_R=0;
        meanAmp_R=0;
        meanVel_R=0;
    end
    
    %% identify saccades
    if numSac_L == 0
        trials(i).sac = trials(i).sac_R;
    else
        trials(i).sac = trials(i).sac_L;
    end
    
    
    saccade_end = detrend(trials(i).sac(:,7));
    saccade_start = detrend(trials(i).sac(:,5));
    
    %% decomp into fast and slow
    switch direction
        case 'Horizontal'
            eye_vel = [trials(i).eye(1,2) ; diff( trials(i).eye(:,2))];
            target_pos = trials(i).target(:,2);
        case 'Vertical'
            eye_vel = [trials(i).eye(1,3) ; diff( trials(i).eye(:,3))];
            target_pos = trials(i).target(:,3);
    end
    eye_vel(isnan(eye_vel))=0;
    
    sacc_on = 1 + trials(i).sac(:,1)/(1000/sample_rate); % converts time to index /2 for 500Hz /4 for 250Hz
    sacc_off = 1 + trials(i).sac(:,2)/(1000/sample_rate);
    
    % get rid of saccades before stimulus onset
    sacc_on(sacc_on<1) = 1;
    sacc_off(sacc_off<2) = 2;
    
    eye_slow = ones(size(eye_vel));
    for sacc_idx = 1:length(sacc_on)
        eye_slow(sacc_on(sacc_idx):sacc_off(sacc_idx)) = 0;
    end
    eye_fast = 1 - eye_slow;
    slow_eye_vel = eye_vel.*eye_slow;
    fast_eye_vel = eye_vel.*eye_fast;
    
    slow_eye_pos = cumsum(slow_eye_vel);
    fast_eye_pos = cumsum(fast_eye_vel);
    eye_pos = cumsum(eye_vel);
    eye_time = trials(i).eye(:,1);
    target_time = trials(i).target(:,1);
    target_time_sec = target_time/1000; % convert to seconds
    eye_time_sec = eye_time/1000;
    
    %% detrend
    slow_eye_pos = detrend(slow_eye_pos);
    fast_eye_pos = fast_eye_pos - fast_eye_pos(1);
    eye_pos = detrend(eye_pos);
    target_pos = detrend(target_pos);
    
    %% scale data to degrees
    pixelWidth = 38.5 / 800; % FIXME  get numbers from data file.
    degPerPixel = atand(pixelWidth/60);  % FIXME  get numbers from data file.
    target_pos = target_pos * degPerPixel;
    slow_eye_pos = slow_eye_pos * degPerPixel;
    eye_pos = eye_pos * degPerPixel;
    fast_eye_pos = fast_eye_pos * degPerPixel;
    
    
    
    %% fit func to data
    %     target_fit_pos = zeros(size(target_pos));
    % t_amp = 109.4;
    % t_rate = 1/sscanf(period,'%f');
    % t_phase = -0.5;
    % trials.eye(:,2) = t_amp*sin(t_phase + 2*pi*t_rate*(1:length(trials.eye(:,2)))/sample_rate);
    
    % init guesses: amp, phase, freq, offset
    B0 = [ 10, 0, 2/sscanf(period,'%f'),0];
    Btarg = nlinfit(target_time_sec,target_pos,@mysin,B0);
    target_fit_pos = mysin(Btarg,target_time_sec);
    
    B0 = [ 10, 0, 1/sscanf(period,'%f'),0];
    Bslow = nlinfit(eye_time_sec,slow_eye_pos,@mysin,B0);
    slow_eye_fit_pos = mysin(Bslow,eye_time_sec);
    
    B0 = [ 10, 0, 1/sscanf(period,'%f'),0];
    Beye = nlinfit(eye_time_sec,eye_pos,@mysin,B0);
    eye_fit_pos = mysin(Beye,eye_time_sec);
    
    
    %% plot eye positions plot 1
    subplot(2,1,1)
    plot(...
        target_time_sec,target_fit_pos,'g:',...
        target_time_sec,target_pos,'g',...
        eye_time_sec,eye_pos,'r',...
        eye_time_sec,eye_fit_pos,'r:'...
        )
    legend('target fit','target','eye','eye fit');
    %     xlim([0 40000])
    title(direction)
    
    %% plot 2
    subplot(2,1,2)
    plot(...
        target_time_sec,target_pos,'g',...
        eye_time_sec,slow_eye_pos,'r',...
        eye_time_sec,slow_eye_fit_pos,'r:',...
        eye_time_sec,fast_eye_pos,'b'...
        )
    legend('target','slow','slow fit','fast');
    
    filename = strrep(filename,'_',' ');
    s = '\n***\n';
    s = [s sprintf( ' file: %s \n trial: %d \n background: %s \n direction: %s \n period: %s \n freq: %.3f\n',...
        filename,i,background,direction,period,1/sscanf(period,'%f sec'))];
    s = [s sprintf( ' composite gain: %.3f phase: %.3f \n slow gain: %.3f phase: %.3f \n',...
        Beye(1)/Btarg(1), Beye(2)-Btarg(2), Bslow(1)/Btarg(1), Bslow(2)-Btarg(2)) ];
    
    %     text(1,0,s);
    fprintf(s); % FIXME not printing the slow phase  wtf?

    %     plot(trials(i).eye(:,1),eye_pos, 'b',trials(i).sac_L(:,1),saccade_start,'g*',trials(i).sac_L(:,2),saccade_end,'r*');
    %     xlabel('Time (msec)'), ylabel('Eye position (pixels)');
    %     legend('composite','target','sacc start','sacc end');
    %     %     legend('Vert Eye Position','Vert Target Position','Start Sac','End Sac');
    % %     ylim([0 600])
    
    
    
    
    %% print results
    if print_flag
        orient landscape
        print('-dpdf','-loose',[filename '_trial_' num2str(i) '.pdf'])
    end
    
    
end

return

%% function to fit
% You need to define your 'model' as a function (possibly in a seperate m-file). For example
%
% >>beta = nlinfit(X,y,myfun,beta0)
%
% where MYFUN is a MATLAB function such as:
% function yhat = myfun(beta, X)
% b1 = beta(1);
% b2 = beta(2);
% yhat = 1 ./ (1 + exp(b1 + b2*X));
%
%
% MYFUN can also be an inline object:
% fun = inline('1 ./ (1 + exp(b(1) + b(2*x))', 'b', 'x')
% nlinfit(x, y, fun, b0)

% t_amp = 109.4;
% t_rate = 1/sscanf(period,'%f');
% t_phase = -0.5;
% trials.eye(:,2) = t_amp*sin(t_phase + 2*pi*t_rate*(1:length(trials.eye(:,2)))/sample_rate);




function yhat = mysin(B,X)
f_amp = B(1);
f_phase = B(2);
f_rate = B(3);
f_offset = B(4);
sample_rate = 250;
yhat = f_offset + f_amp * sin(f_phase + 2*pi * f_rate * (1:length(X))' / sample_rate);

return


