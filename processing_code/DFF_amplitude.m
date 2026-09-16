
% This code extracts features of epochs from brainstom database and plots



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
band = [30 90];

%% ===================== EXTRACT ========================
for ii = 1:length(conditionNames)

    cond = conditionNames{ii};

    % Select files
    sFilesERP = bst_process('CallProcess', ...
        'process_select_files_data', [], [], ...
        'subjectname',   [], ...
        'condition',     cond, ...
        'tag',           '(#', ...
        'includebad',    0, ...
        'includeintra',  0, ...
        'includecommon', 0);

    allPhase = [];

for i = 1:length(sFilesERP)

    fullFile = fullfile(ProtocolInfo.STUDIES, ...
                        sFilesERP(i).FileName);

    signal = load(fullFile);

    % Time x Channels
    [F_phase,F_amp,F_band] = getBandFeatures(signal, band, Fs);
    
    %baseline correction
    F_amp = baselineCorrect(F_amp); 

    % Time x Channels x Subjects
    allFeature(:,:,i) = F_amp;

end

% Mean across subjects/files
MeanAmp = mean(allFeature, 3, 'omitnan');

% 95% CI across subjects/files
N  = size(allFeature,3);
SE = std(allFeature, 0, 3, 'omitnan') ./ sqrt(N);
CI95 = 1.96 * SE;

t = linspace(-0.5, 0.5, size(allFeature,1));

% compressing files
MeanAmp = single(MeanAmp);
CI95 = single(CI95);
allFeature = single(allFeature);
t = single(t);

save(fullfile(outDir, sprintf('%s_Abs%d%d.mat', cond, band(1), band(2))), ...
    't', 'MeanAmp', 'CI95', 'allFeature', '-v7');

fprintf('%d/%d (%s) \n',ii, length(conditionNames), cond);


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