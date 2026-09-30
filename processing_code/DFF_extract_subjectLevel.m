% This code extracts features of epochs from brainstorm database and plots
% Get subjects in the current BST protocol
subjects_bst = bst_get('ProtocolSubjects');
SubjectNames = {subjects_bst.Subject.Name};

% INITIALIZATION
band = [0.1 30];
band = [30 90];

trig = "cue";
baselineWindow = [-0.3 0];   % s, relative to Cue onset (t=0)

% Remove Group analysis
SubjectNames(contains(SubjectNames,'Group')) = [];
sStudies = bst_get('ProtocolStudies');
conditionNames = strings(numel(sStudies.Study),1);
for i = 1:numel(sStudies.Study)
    conditionNames(i) = string(sStudies.Study(i).Condition);
end
conditionNames = unique(conditionNames);
conditionNames = conditionNames(startsWith(conditionNames,trig));
disp(conditionNames);
ProtocolInfo = bst_get('ProtocolInfo');
outDir = fullfile(ProtocolInfo.STUDIES, 'Group_analysis');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
Fs = 512;


%% ===================== EXTRACT ========================
for ii = 1:length(conditionNames)
    cond = conditionNames{ii};

    % Select files (all trials, all subjects, for this condition)
    sFilesERP = bst_process('CallProcess', ...
        'process_select_files_data', [], [], ...
        'subjectname',   [], ...
        'condition',     cond, ...
        'tag',           'WAvg', ...
        'includebad',    0, ...
        'includeintra',  0, ...
        'includecommon', 0);

    if isempty(sFilesERP)
        fprintf('%d/%d (%s) - no files found, skipping\n', ii, length(conditionNames), cond);
        continue;
    end

    % ---- Group trial files by subject ----
    subjNamesAll = {sFilesERP.SubjectName};
    uniqueSubj   = unique(subjNamesAll, 'stable');
    nSub         = numel(uniqueSubj);

    allFeature  = [];              % initialized once T,C are known: T x C x nSub  (Hilbert amplitude)
    allBand     = [];              % initialized once T,C are known: T x C x nSub  (raw band-filtered waveform)
    SubjectName = cell(1, nSub);   % subject label per slice of allFeature (dim 3)
    nTrialsUsed = zeros(1, nSub);  % how many trials contributed to each subject's mean

    t = [];   % epoch time vector, captured once from the first usable trial

    for si = 1:nSub
        subj = uniqueSubj{si};
        trialIdx = find(strcmp(subjNamesAll, subj));

        subjAmpSum  = [];
        subjBandSum = [];
        nOK = 0;

        for k = 1:numel(trialIdx)
            i = trialIdx(k);
            fullFile = fullfile(ProtocolInfo.STUDIES, sFilesERP(i).FileName);
            signal = load(fullFile);

            % Real epoch time vector (seconds, relative to event), taken
            % directly from the Brainstorm data file rather than assumed
            epochTime = signal.Time;

            % Time x Channels
            [~, F_amp, F_band] = getBandFeatures(signal, band, Fs);

            % Baseline correction at the single-trial level, BEFORE
            % averaging across trials within the subject. Trims edge
            % samples and returns the matching (trimmed) time vector.
            [F_amp, trimmedTime]  = baselineCorrect(F_amp, epochTime, baselineWindow);
            [F_band, ~]           = baselineCorrect(F_band, epochTime, baselineWindow);

            if isempty(t)
                t = trimmedTime;   % capture the true epoch time axis once
            end

            if isempty(subjAmpSum)
                subjAmpSum  = F_amp;
                subjBandSum = F_band;
            else
                subjAmpSum  = subjAmpSum + F_amp;
                subjBandSum = subjBandSum + F_band;
            end
            nOK = nOK + 1;
        end

        if nOK == 0
            continue; % no usable trials for this subject in this condition
        end

        % Trial-weighted average within subject (equal weight per trial
        % => plain mean over trials == weighted by trial count)
        subjAmpMean  = subjAmpSum  / nOK;
        subjBandMean = subjBandSum / nOK;

        if isempty(allFeature)
            [T, C] = size(subjAmpMean);
            allFeature = nan(T, C, nSub);
            allBand    = nan(T, C, nSub);
        end

        allFeature(:,:,si) = subjAmpMean;
        allBand(:,:,si)    = subjBandMean;
        SubjectName{si}    = subj;
        nTrialsUsed(si)    = nOK;
    end

    % Drop any subject slots that ended up empty (no usable trials)
    keepSubj = ~cellfun(@isempty, SubjectName);
    allFeature  = allFeature(:,:,keepSubj);
    allBand     = allBand(:,:,keepSubj);
    SubjectName = SubjectName(keepSubj);
    nTrialsUsed = nTrialsUsed(keepSubj);

    % Mean across SUBJECTS (each subject already a within-subject mean)
    MeanAmp  = mean(allFeature, 3, 'omitnan');
    MeanBand = mean(allBand, 3, 'omitnan');

    % Between-subject SE and 95% CI (subject variation only)
    N        = size(allFeature, 3);
    SE       = std(allFeature, 0, 3, 'omitnan') ./ sqrt(N);
    CI95     = 1.96 * SE;
    SE_band  = std(allBand, 0, 3, 'omitnan') ./ sqrt(N);
    CI95_band = 1.96 * SE_band;

    % compressing files
    MeanAmp     = single(MeanAmp);
    SE          = single(SE);
    CI95        = single(CI95);
    allFeature  = single(allFeature);
    MeanBand    = single(MeanBand);
    SE_band     = single(SE_band);
    CI95_band   = single(CI95_band);
    allBand     = single(allBand);
    t           = single(t);

    save(fullfile(outDir, sprintf('%s_Abs%d%d.mat', cond, round(band(1)), round(band(2)))), ...
        't', 'MeanAmp', 'SE', 'CI95', 'allFeature', ...
        'MeanBand', 'SE_band', 'CI95_band', 'allBand', ...
        'SubjectName', 'nTrialsUsed', '-v7');

    fprintf('%d/%d (%s) - %d subjects \n', ii, length(conditionNames), cond, N);
end

%% ============ Functions =======
function [F_phase,F_amp,F_band] = getBandFeatures(F, band, Fs)
%GETBANDFEATURES Extract band-limited phase and amplitude.
%
% Inputs:
%   F     - structure with field F (channels x time)
%   band  - [low high] Hz
%   Fs    - sampling frequency
%
% Outputs:
%   F_phase - instantaneous phase (time x channels)
%   F_amp   - instantaneous amplitude (time x channels)
%   F_band  - filtered signal (time x channels)
% Butterworth band-pass
    [b,a] = butter(4, band/(Fs/2), 'bandpass');
% Zero-phase filtering
    F_band = filtfilt(b,a,double(F.F'));
% Analytic signal
    H = hilbert(F_band);
% Phase
    F_phase = angle(H);
% Amplitude
    F_amp = abs(H);
end

function [F_bc, trimmedTime] = baselineCorrect(F_in, epochTime, baselineWindow)
%BASELINECORRECT Subtract mean of an explicit pre-stimulus window as baseline.
%
% Input:
%   F_in           - time x channels signal (amplitude envelope OR filtered waveform)
%   epochTime      - 1 x time, original epoch time vector (seconds)
%   baselineWindow - [tStart tEnd] in seconds (relative to t=0), e.g. [-0.3 0]
%
% Output:
%   F_bc        - baseline-corrected signal (time x channels)
%   trimmedTime - time vector matching F_bc after edge trimming
    nTrim = 50;
    nTime = size(F_in, 1);

    F_in = F_in(nTrim+1 : nTime-nTrim, :);
    trimmedTime = epochTime(nTrim+1 : nTime-nTrim);

    baselineMask = trimmedTime >= baselineWindow(1) & trimmedTime <= baselineWindow(2);
    if ~any(baselineMask)
        error('baselineCorrect:emptyWindow', ...
            'Baseline window [%.3f %.3f] s has no samples in the (trimmed) epoch [%.3f %.3f] s.', ...
            baselineWindow(1), baselineWindow(2), trimmedTime(1), trimmedTime(end));
    end

    baselineMean = mean(F_in(baselineMask, :), 1);   % 1 x channels, over the chosen window
    F_bc = F_in - baselineMean;                       % broadcast subtraction across time
end