% Get subjects in the current BST protocol
subjects_bst = bst_get('ProtocolSubjects');
SubjectNames = {subjects_bst.Subject.Name};

% Remove Group analysis
SubjectNames(contains(SubjectNames,'Group')) = [];

% conditionName = { ...
%     'stim2_two', 'stim2_one', ...
%     'stim1_two', 'stim1_one' ...
% };

ProtocolInfo = bst_get('ProtocolInfo');

outDir = fullfile(ProtocolInfo.STUDIES, 'Group_analysis');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

Fs = 512;
band = [30 50];

for ii = 1:length(conditionName)

    cond = conditionName{ii};

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

    % Time x Channels x Subjects
    allFeature(:,:,i) = F_amp;

end

% Mean across subjects/files
MeanPhase = mean(allFeature, 3, 'omitnan');

% 95% CI across subjects/files
N  = size(allFeature,3);
SE = std(allFeature, 0, 3, 'omitnan') ./ sqrt(N);
CI95 = 1.96 * SE;

t = linspace(-0.5, 0.5, size(allFeature,1));

save(fullfile(outDir, ...
    sprintf('%s_gammaAbs%d%d.mat', cond, band(1), band(2))), ...
    't', 'MeanPhase', 'CI95', 'allFeature');


end

conds = [0 1 3 5 7 9];

% Load channel info once
chan = load(fullfile(ProtocolInfo.STUDIES, ...
    'Group_analysis/@default_study/channel.mat'));
chanNames = {chan.Channel.Name};

chanName = 'POz';
ch = find(strcmp(chanNames, chanName));

figure('Color','w','Position',[100 50 800 1200]);

for i = 1:numel(conds)

    n = conds(i);

    subplot(numel(conds),1,i);
    hold on

    file1 = fullfile(outDir, ...
        sprintf('stim1_two_%d_gammaAbs%d%d.mat', ...
        n, band(1), band(2)));

    file2 = fullfile(outDir, ...
        sprintf('stim1_one_%d_gammaAbs%d%d.mat', ...
        n, band(1), band(2)));

    h1 = [];
    h2 = [];

    % ---- Perceived 2 flashes (RED) ----
    if exist(file1,'file')

        S1 = load(file1);

        fill([S1.t fliplr(S1.t)], ...
             [(S1.MeanPhase(:,ch)-S1.CI95(:,ch))' ...
              fliplr((S1.MeanPhase(:,ch)+S1.CI95(:,ch))')], ...
             'r', ...
             'FaceAlpha',0.2, ...
             'EdgeColor','none', ...
             'HandleVisibility','off');

        h1 = plot(S1.t, S1.MeanPhase(:,ch), ...
                  'r','LineWidth',2);
    end

    % ---- Perceived 1 flash (BLUE) ----
    if exist(file2,'file')

        S2 = load(file2);

        fill([S2.t fliplr(S2.t)], ...
             [(S2.MeanPhase(:,ch)-S2.CI95(:,ch))' ...
              fliplr((S2.MeanPhase(:,ch)+S2.CI95(:,ch))')], ...
             'b', ...
             'FaceAlpha',0.2, ...
             'EdgeColor','none', ...
             'HandleVisibility','off');

        h2 = plot(S2.t, S2.MeanPhase(:,ch), ...
                  'b','LineWidth',2);
    end

    x = xline(0,'--k','LineWidth',1.5);
    x.Annotation.LegendInformation.IconDisplayStyle = 'off';

    xlim([-0.2 0.2]);

    title(sprintf('ISI %d ms', n*7));

    ylabel('Amplitude (\\muV)');

    if i == numel(conds)
        xlabel('Time (s)');
    end

    grid on
    box off

    % Legend on every subplot
    hh = [h1 h2];
    hh = hh(isgraphics(hh));

    labels = {};
    if ~isempty(h1) && isgraphics(h1)
        labels{end+1} = 'Perceived 2 flashes';
    end
    if ~isempty(h2) && isgraphics(h2)
        labels{end+1} = 'Perceived 1 flash';
    end

    if ~isempty(hh)
        legend(hh, labels, 'Location', 'best');
    end

end

sgtitle(sprintf('First flash locked ERP (%s, %d-%d Hz)', ...
    chanName, band(1), band(2)), ...
    'FontSize',16, ...
    'FontWeight','bold');

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