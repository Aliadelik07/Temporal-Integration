% extraction of recovery rate
% Grabing all the preprocessed files
ProtocolInfo = bst_get('ProtocolInfo');
% initialization
sfreq = 512;
tWin = 0.03; % s

onset = round(0.17 * sfreq);

band = [30 50];
chanSel   = {'PO7','PO3','O1','O2','PO4','PO8'}; chanLabel = 'Laterized Occipital';
% chanSel   = {'POz','Oz'}; chanLabel = 'Occipital Central';

% Load channel info once
f = dir(fullfile(ProtocolInfo.STUDIES, '**', '*channel.mat')); f = f(1,1);
chan = load(fullfile(f.folder,f.name));
chanNames = {chan.Channel.Name};
ch = find(ismember(chanNames, chanSel));   % indices of all selected channels

if numel(ch) ~= numel(chanSel)
    warning('Only found %d/%d channels of chanSel in channel file.', numel(ch), numel(chanSel));
end

sFilesList = bst_process('CallProcess', 'process_select_files_data', [], [], ...
    'subjectname',   '', ...
    'condition',     '', ...
    'tag',           'Raw | band(0.25-95Hz) | notch(50Hz) | interpbad', ...
    'includebad',    0, ...
    'includeintra',  0, ...
    'includecommon', 0);

for ii = 1:length(sFilesList)
    % load data
    subName = sFilesList(ii).SubjectName;
    DataMat = in_bst_data(sFilesList(ii).FileName);

    % take the recording
    [F, TimeVector] = in_fread(DataMat.F, [], [], [], []);

    % Channel choice: average across the lateralized occipital channels
    sig = double(mean(F(ch,:), 1));

    % Bandpass
    [b,a] = butter(4,band/(sfreq/2),'bandpass');
    sig = filtfilt(b,a,sig);

    %% stim1 events
    iStim = find(strcmp({DataMat.F.events.label},'stim1'));
    evtTimes = DataMat.F.events(iStim).times;
    evtSamples = round(evtTimes * sfreq);
    nWin = round(tWin * sfreq);
    peakAmp1 = nan(numel(evtSamples),1);
    peakLat1 = nan(numel(evtSamples),1);
    for k = 1:numel(evtSamples)
        s0 = evtSamples(k);
        if s0+nWin <= length(sig) && s0-nWin >= 1
            seg = sig(s0+onset:s0+onset+nWin);
            [pks,locs] = findpeaks(seg);
            if ~isempty(pks)
                [peakAmp1(k), idx] = max(pks);
                peakLat1(k) = (locs(idx)-1)/sfreq;
                baselineSeg = sig(s0-nWin:s0);
                baselineMean = mean(baselineSeg);
                peakAmp1(k) = peakAmp1(k) - baselineMean;
            end
        end
    end

    %% stim2 events
    iStim = find(strcmp({DataMat.F.events.label},'stim2')); 
    evtTimes = DataMat.F.events(iStim).times;
    evtSamples = round(evtTimes * sfreq);
    nWin = round(tWin * sfreq);
    peakAmp2 = nan(numel(evtSamples),1);
    peakLat2 = nan(numel(evtSamples),1);
    for k = 1:numel(evtSamples)
        s0 = evtSamples(k);
        if s0+nWin <= length(sig)
            seg = sig(s0+onset:s0+onset+nWin);
            [pks,locs] = findpeaks(seg);
            if ~isempty(pks)
                [peakAmp2(k), idx] = max(pks);
                peakLat2(k) = (locs(idx)-1)/sfreq;
                baselineSeg = sig(s0-nWin:s0);
                baselineMean = mean(baselineSeg);
                peakAmp2(k) = peakAmp2(k) - baselineMean;
            end
        end
    end

    %% -------------- importing trialList --------------
    filePath = fullfile('D:\DFF_data', subName, subName + ".csv");
    T = readtable(filePath);
    T.peakAmp1 = peakAmp1;
    T.peakLat1 = peakLat1;
    T.peakAmp2 = peakAmp2;
    T.peakLat2 = peakLat2;
    outFile = fullfile('D:\DFF_data', subName, subName + "RR.csv");
    writetable(T, outFile);
    fprintf('%d/%d (%s) \n',ii, length(sFilesList), subName);

    %% comparing the two peaks per subject
    figure;
    histogram(peakAmp1, 30, ...
        'Normalization', 'probability', ...
        'FaceColor', 'b', ...
        'FaceAlpha', 0.5);
    hold on
    histogram(peakAmp2, 30, ...
        'Normalization', 'probability', ...
        'FaceColor', 'r', ...
        'FaceAlpha', 0.5);
    xlabel('Peak amplitude');
    ylabel('Probability');
    title(sprintf('%s: Peak of %d-%d Hz (%s)', subName, band(1), band(2), chanLabel));
    legend('Stim1','Stim2');
    grid on;
end