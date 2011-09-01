function [eye,target] = targfit(filename,print_flag)
% targfit - fit ideal funtion to eye trace data to estimate gain and lag of
% targfit(filename, print_flag) 
% - filename is the name of the file to load. if not given the a file select
% dialog is presented.
% - print_flag set to true to print results to pdf
% participant eye motion. Eye traces are broken into fast and slow
% components. The fast components are the saccades. Right now saccade tags
% generated by the eyelink are used. We plan to write our own saccade
% identification routines.
% Data is prepared by first converting from .edf to asc using the GUI
% converter from SR Research. Then our script process_all_asc_data is run
% to preprocess and convert the asc data to .mat files.

% init vars to be loaded from filename
trials = []; % the eye tracking data, load from filename
collectedData = {}; % left, right, or both eyes?; load from filename

%% load data
% warning off %#ok<WNOFF>
if ~exist('filename','var') % if no filename given on command line then ask with gui
    [filename,pathname] = uigetfile;
    load([pathname filename])
else
    load(filename) % load the data
end

if ~exist('print_flag','var') % whether or not to print the results to a pdf file
    print_flag = false;
end

%% fourier analysis for comparison
f_eye = fouri(trials,direction,sample_rate);

% view trials
numTrials = size(trials,2);
for i=1:numTrials
    
    figure(i)
    numSac_L=size(trials(i).sac_L,1);
    if numSac_L > 0
%         a=mean(trials(i).sac_L,1);
%         meanDur_L=a(3);
%         meanAmp_L=a(8);
%         meanVel_L=a(9);
    else
        trials(i).sac_L = [0 0 0 0 0 0 0 0 0]; %#ok<*AGROW>
%         meanDur_L=0;
%         meanAmp_L=0;
%         meanVel_L=0;
    end
    numSac_R=size(trials(i).sac_R,1);
    if numSac_R > 0
%         a=mean(trials(i).sac_R,1);
%         meanDur_R=a(3);
%         meanAmp_R=a(8);
%         meanVel_R=a(9);
    else
        trials(i).sac_R = [0 0 0 0 0 0 0 0 0];
%         meanDur_R=0;
%         meanAmp_R=0;
%         meanVel_R=0;
    end

    %% identify saccades
    if numSac_L == 0
        trials(i).sac = trials(i).sac_R;
    else
        trials(i).sac = trials(i).sac_L;
    end
    
    
%     saccade_end = detrend(trials(i).sac(:,7));
%     saccade_start = detrend(trials(i).sac(:,5));
    
    %% decomp into fast and slow FIXME change to 2D analysis instead of picking one direction
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
    
    %     target_pos = resample(target_pos,length(eye_pos),length(target_pos));
    %     target_time_sec = resample(target_time_sec,length(eye_pos),length(target_time_sec));
    
    %% fit func to data
    %     statopts = statset('Display','iter');
    statopts = [];
    
    % init guesses: amp, phase, freq, offset
    % get amplitude guess from actual target motion
    amp_guess = (max(target_pos) - min(target_pos)); % FIXME - should amp be divide by 2?
    offset_guess = (max(target_pos) + min(target_pos))/2;
    
    B0 = [ amp_guess, 0, 1/sscanf(period,'%f'),offset_guess]; % fit to target motion
    Btarg = nlinfit(target_time_sec,target_pos,@mysin,B0,statopts);
    target_fit_pos = mysin(Btarg,target_time_sec);
    
%     B0 = [ 10, Btarg(2), 1/sscanf(period,'%f'),0]; % fit composite eye motion
    Beye = nlinfit(eye_time_sec,eye_pos,@mysin,Btarg,statopts); % use target result for init guess
    eye_fit_pos = mysin(Beye,eye_time_sec);
    
%     B0 = [ 10, Btarg(2), 1/sscanf(period,'%f'),0]; % fit slow eye data
    Bslow = nlinfit(eye_time_sec,slow_eye_pos,@mysin,Beye,statopts); % use composite fit for init guess
    slow_eye_fit_pos = mysin(Bslow,eye_time_sec);
    
    %% collect data for output
    eye(i).pos = eye_pos;
    eye(i).time = eye_time_sec;
    eye(i).fit = eye_fit_pos;
    target(i).pos = target_pos;
    target(i).time = target_time_sec;
    target(i).fit = target_fit_pos;
    
    
    clf
    %% plot eye positions plot 1
    subplot(3,1,1)
    plot(...
        target_time_sec,target_fit_pos,'g:',...
        target_time_sec,target_pos,'g',...
        eye_time_sec,eye_pos,'r',...
        eye_time_sec,eye_fit_pos,'r:'...
        )
    legend('target fit','target','eye','eye fit','Location','NorthEastOutside');
    %     xlim([0 40000])
    title(direction)
    
    %% plot 2
    subplot(3,1,2)
    plot(...
        target_time_sec,target_pos,'g',...
        eye_time_sec,slow_eye_pos,'r',...
        eye_time_sec,slow_eye_fit_pos,'r:',...
        eye_time_sec,fast_eye_pos,'b'...
        )
    legend('target','slow','slow fit','fast','Location','NorthEastOutside');
    
    
    %% build ouput string
    filename = strrep(filename,'_',' ');
    s = '';
    s = [s sprintf( ' file: %s, trial: %d, eye: %s \n',filename,i,collectedData{3})];
    s = [s sprintf( ' background: %s',background)];
    
    if exist('checkSize','var')
        s = [s sprintf(', check size: %s',checkSize)];
    end
    
    s = [s sprintf( '\n direction: %s, period: %s, freq: %.3f \n',direction,period,1/sscanf(period,'%f sec'))];
    s = [s sprintf( ' target size: %s,',targetSize)];
    
    if exist('targetColor','var')
        s = [s sprintf(', targetColor: %s',targetColor)];
    end
    
    s = [s sprintf( '\n COMP gain: %.3f, phase: %.3f | fourier gain: %.3f, fourier phase: %.3f ',...
        Beye(1)/Btarg(1), rad2deg(Beye(2)-Btarg(2)), f_eye(i).gain, f_eye(i).phase) ];
    s = [s sprintf( '\n SLOW gain: %.3f, phase: %.3f | fourier gain: %.3f, fourier phase: %.3f \n',...
        Bslow(1)/Btarg(1), rad2deg(Bslow(2)-Btarg(2)), f_eye(i).slow.gain, f_eye(i).slow.phase) ];
    s = [s sprintf(' fit targ freq: %.3f, func fit eye freq: %.3f, fourier freq: %.3f  ',...
        Btarg(3),Beye(3),f_eye(i).freq) ];
    
    
    fprintf(s);
    fprintf('***');
    
    %% plot 3  text output
    subplot(3,1,3)
    plot(zeros(10,1))
    axis off
    ylim([0 10])
    text(1,5,s)
    
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
% init guesses: 1 amp, 2 phase, 3 freq, 4 offset
function yhat = mysin(B,X)

yhat = B(4) + B(1) * cos( B(2) +  2*pi * B(3) * X);

return


