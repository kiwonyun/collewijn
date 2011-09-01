function eye = fouri(trials,direction,sample_rate)
% fouri - fourier analysis of eye trace data to estimate gain and lag of
% participant eye motion. Eye traces are broken into fast and slow
% components. The fast components are the saccades. Right now saccade tags
% generated by the eyelink are used. We plan to write our own saccade
% identification routines.
% Data is prepared by first converting from .edf to asc using the GUI
% converter from SR Research. Then our script process_all_asc_data is run
% to preprocess and convert the asc data to .mat files.
%
% this was collewijn with ploting and some other stuff removed

numTrials = size(trials,2);
for i=1:numTrials
    
    %     figure(i)
    numSac_L=size(trials(i).sac_L,1);
    if numSac_L > 0
    else
        trials(i).sac_L = [0 0 0 0 0 0 0 0 0]; %#ok<*AGROW>
    end
    numSac_R=size(trials(i).sac_R,1);
    if numSac_R > 0
    else
        trials(i).sac_R = [0 0 0 0 0 0 0 0 0];
    end
    
    %% identify saccades
    if numSac_L == 0
        trials(i).sac = trials(i).sac_R;
    else
        trials(i).sac = trials(i).sac_L;
    end
    
    
    %% decomp into fast and slow plot 1
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
%     eye_fast = 1 - eye_slow;
    slow_eye_vel = eye_vel.*eye_slow;
%     fast_eye_vel = eye_vel.*eye_fast;
    slow_eye_pos = cumsum(slow_eye_vel);
%     fast_eye_pos = cumsum(fast_eye_vel);
    eye_pos = cumsum(eye_vel);
%     eye_time = trials(i).eye(:,1);
%     target_time = trials(i).target(:,1);
    
    %% detrend
    slow_eye_pos = detrend(slow_eye_pos);
%     fast_eye_pos = fast_eye_pos - fast_eye_pos(1);
    eye_pos = detrend(eye_pos);
    target_pos = detrend(target_pos);
        
    %% zero pad the data
    
    L     = length(eye_pos);
    Ltarg = length(target_pos);
    %     Lslow = length(slow_eye_pos);
    
    Z = zeros(L,1);
    Ztarg = zeros(Ltarg,1);
    
    eye_pos = eye_pos .* hamming(length(eye_pos));
    slow_eye_pos = slow_eye_pos .* hamming(length(slow_eye_pos));
    target_pos = target_pos .* hamming(length(target_pos));
    
    eye_pos = [Z; eye_pos; Z];
    slow_eye_pos = [Z; slow_eye_pos; Z];
%     fast_eye_pos = [Z; fast_eye_pos; Z];
    target_pos = [Ztarg; target_pos; Ztarg];
    
%     eye_time = [Z; eye_time; Z+eye_time(end)];
%     target_time = [Ztarg; target_time; Ztarg+target_time(end)];

    L     = length(eye_pos);
    Ltarg = length(target_pos);

    %% fourier amplitude
    %     subplot(2,2,3)
    Fs = sample_rate  ; % sample rate Hz
    Fs_stim = 120 ; % monitor refresh freq Hz

    NFFT = Ltarg * ( Fs/Fs_stim );
    NFFTtarg = Ltarg;     
    Y  = fft(eye_pos,NFFT)/L;
    Y2 = fft(target_pos,NFFTtarg)/Ltarg;
    Y3 = fft(slow_eye_pos,NFFT)/L;
    
%     f = Fs/2*linspace(0,1,NFFT/2+1);
    f_targ = Fs_stim/2*linspace(0,1,NFFTtarg/2+1);
    
    traceRange = int32(1:NFFT/2+1);
    traceRangeTarg = int32(1:NFFTtarg/2+1);
    eye_amp = 2*abs(Y(traceRange)); % calculate amplitude at freq
    targ_amp = 2*abs(Y2(traceRangeTarg));
    slow_eye_amp = 2*abs(Y3(traceRange));
    
    %% calculate phase
    eye_phase = angle(Y(traceRange));
    targ_phase = angle(Y2(traceRangeTarg));
    slow_eye_phase = angle(Y3(traceRange));
    eye_phase = eye_phase(1:length(targ_phase)) - targ_phase;
    slow_eye_phase = slow_eye_phase(1:length(targ_phase)) - targ_phase;
    
    slow_eye_phase(slow_eye_phase>6) =  slow_eye_phase(slow_eye_phase>6)-2*pi; % get rid of wrap.
    eye_phase(eye_phase>6) =  eye_phase(eye_phase>6)-2*pi;
    
    % numerically diff to get curvature of function
    targ_diff2 = [0;0; diff(diff(targ_amp))];
    
    % adjust to cut off analysis at low freq end of spectrum
    targ_diff2_ignore = 1;
    [~,targ_diff2_min_idx] = min(targ_diff2(targ_diff2_ignore:end)); % find curvature minima
    targ_diff2_min_idx = targ_diff2_ignore + targ_diff2_min_idx; % shift index back to right place

    %% calculate gain
    eye_gain = eye_amp(1:length(targ_amp))./targ_amp;
    slow_eye_gain = slow_eye_amp(1:length(targ_amp))./targ_amp;
    
    eye(i).gain = eye_gain(targ_diff2_min_idx);
    eye(i).slow.gain = slow_eye_gain(targ_diff2_min_idx);
    eye(i).phase = rad2deg(eye_phase(targ_diff2_min_idx));
    eye(i).slow.phase = rad2deg(slow_eye_phase(targ_diff2_min_idx));
    eye(i).freq = f_targ(targ_diff2_min_idx);
    
    
end


