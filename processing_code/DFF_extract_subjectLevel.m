% This code extracts features of epochs from brainstorm database and plots
% Get subjects in the current BST protocol
subjects_bst = bst_get('ProtocolSubjects');
SubjectNames = {subjects_bst.Subject.Name};
% Remove Group analysis
SubjectNames(contains(SubjectNames,'Group')) = [];
sStudies = bst_get('ProtocolStudies');
conditionNames = strings(numel(sStudies.Study),1);
for i = 1:numel(sStudies.Study)
    conditionNames(i) = string(sStudies.Study(i).Condition);
end
conditionNames = unique(conditionNames);
conditionNames = conditionNames(startsWith(conditionNames,"stim"));
disp(conditionNames);
ProtocolInfo = bst_get('ProtocolInfo');
outDir = fullfile(ProtocolInfo.STUDIES, 'Group_analysis');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
Fs = 512;
band = [0.1 30];
band = [8 12];
%% ===================== EXTRACT ========================
for ii = 1:length(conditionNames)
    cond = conditionNames{ii};

    % Select files (all trials, all subjects, for this condition)
    sFilesERP = bst_process('CallProcess', ...
        'process_select_files_data', [], [], ...
        'subjectname',   [], ...
        'condition',     cond, ...
        'tag',           '(#', ...
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

    allFeature  = [];              % initialized once T,C are known: T x C x nSub
    SubjectName = cell(1, nSub);   % subject label per slice of allFeature (dim 3)
    nTrialsUsed = zeros(1, nSub);  % how many trials contributed to each subject's mean

    for si = 1:nSub
        subj = uniqueSubj{si};
        trialIdx = find(strcmp(subjNamesAll, subj));

        subjAmpSum = [];
        nOK = 0;

        for k = 1:numel(trialIdx)
            i = trialIdx(k);
            fullFile = fullfile(ProtocolInfo.STUDIES, sFilesERP(i).FileName);
            signal = load(fullFile);

            % Time x Channels
            [~, F_amp, ~] = getBandFeatures(signal, band, Fs);

            % Baseline correction at the single-trial level, BEFORE
            % averaging across trials within the subject
            F_amp = baselineCorrect(F_amp);

            if isempty(subjAmpSum)
                subjAmpSum = F_amp;
            else
                subjAmpSum = subjAmpSum + F_amp;
            end
            nOK = nOK + 1;
        end

        if nOK == 0
            continue; % no usable trials for this subject in this condition
        end

        % Trial-weighted average within subject (equal weight per trial
        % => plain mean over trials == weighted by trial count)
        subjAmpMean = subjAmpSum / nOK;

        if isempty(allFeature)
            [T, C] = size(subjAmpMean);
            allFeature = nan(T, C, nSub);
        end

        allFeature(:,:,si) = subjAmpMean;
        SubjectName{si}    = subj;
        nTrialsUsed(si)    = nOK;
    end

    % Drop any subject slots that ended up empty (no usable trials)
    keepSubj = ~cellfun(@isempty, SubjectName);
    allFeature  = allFeature(:,:,keepSubj);
    SubjectName = SubjectName(keepSubj);
    nTrialsUsed = nTrialsUsed(keepSubj);

    % Mean across SUBJECTS (each subject already a within-subject mean)
    MeanAmp = mean(allFeature, 3, 'omitnan');

    % Between-subject SE and 95% CI (subject variation only)
    N    = size(allFeature, 3);
    SE   = std(allFeature, 0, 3, 'omitnan') ./ sqrt(N);
    CI95 = 1.96 * SE;

    nTimeOut = size(allFeature, 1);
    t = linspace(-0.5, 0.5, nTimeOut); % NOTE: adjust if baselineCorrect's
                                        % nTrim changes the true epoch span

    % compressing files
    MeanAmp     = single(MeanAmp);
    SE          = single(SE);
    CI95        = single(CI95);
    allFeature  = single(allFeature);
    t           = single(t);

    save(fullfile(outDir, sprintf('%s_Abs%d%d.mat', cond, round(band(1)), round(band(2)))), ...
        't', 'MeanAmp', 'SE', 'CI95', 'allFeature', 'SubjectName', 'nTrialsUsed', '-v7');

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

function F_amp_bc = baselineCorrect(F_amp)
%BASELINECORRECT Subtract mean of first half of time samples as baseline.
%
% Input:
%   F_amp - time x channels amplitude/envelope
%
% Output:
%   F_amp_bc - baseline-corrected amplitude (time x channels)
    nTrim = 50;
    nTime = size(F_amp, 1);
    F_amp = F_amp(nTrim+1 : nTime-nTrim, :);
    nTime = size(F_amp, 1);
    halfIdx = 1:floor(nTime/2);
    baselineMean = mean(F_amp(halfIdx, :), 1);   % 1 x channels
    F_amp_bc = F_amp - baselineMean;              % broadcast subtraction across time
end
