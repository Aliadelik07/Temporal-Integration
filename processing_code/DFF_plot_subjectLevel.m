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

ProtocolInfo = bst_get('ProtocolInfo');

outDir = fullfile(ProtocolInfo.STUDIES, 'Group_analysis');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

Fs = 512;
band = [30 50];
band = [0 30];
% band = [8 12];
% ---- Channels to average ----
% chanSel   = {'PO7','PO3','POz','O1','Oz','O2','PO4','PO8'}; chanLabel = 'Occipital';
% chanSel   = {'O2','PO4','PO8'}; chanLabel = 'Occipital Right';
% chanSel   = {'PO7','PO3','O1'}; chanLabel = 'Occipital Left';
% chanSel   = {'PO7','PO3','O1','O2','PO4','PO8'}; chanLabel = 'Laterized Occipital';
chanSel   = {'POz','Oz'}; chanLabel = 'Occipital Central';

%% ================= SETUP (shared across all figures) =================

% Load channel info once
f = dir(fullfile(ProtocolInfo.STUDIES, '**', '*channel.mat'));
f = f(1,1);
chan = load(fullfile(f.folder,f.name));
chanNames = {chan.Channel.Name};

[tf, loc] = ismember(chanSel, chanNames);
if ~all(tf)
    error('Channel(s) not found in channel file: %s', strjoin(chanSel(~tf), ', '));
end
ch = loc;   % vector of channel indices to be averaged

conds      = [0 1 3 5 7 9];
validities = {'valid','neutral','invalid'};
percepts   = {'one','two'};

% ---- Preload every data file exactly once, channel-average immediately.
%      cache.(percept).(validity){condIdx} is a struct with:
%        .t            1xT time vector
%        .SubjectName  1xNsub cell array of subject names
%        .subjMean     T x Nsub  (allFeature already averaged over ch)
%        .nTrials      1xNsub trial counts per subject (for weighting)
cache = struct();
for p = 1:numel(percepts)
    percept = percepts{p};
    for iV = 1:numel(validities)
        validity = validities{iV};
        for i = 1:numel(conds)
            n = conds(i);
            fpath = fullfile(outDir, ...
                sprintf('stim1_%s_%d_%s_Abs%d%d.mat', ...
                percept, n, validity, band(1), band(2)));

            if ~exist(fpath,'file')
                cache.(percept).(validity){i} = [];
                continue;
            end

            S = load(fpath);

            if ~isfield(S,'SubjectName') || ~isfield(S,'allFeature')
                error(['File %s is missing SubjectName/allFeature. ' ...
                       'Re-run the extraction script with subject-level ' ...
                       'grouping before plotting.'], fpath);
            end

            subjMean = squeeze(mean(S.allFeature(:,ch,:), 2, 'omitnan')); % T x Nsub

            if isfield(S,'nTrialsUsed')
                nTrials = S.nTrialsUsed;
            else
                nTrials = ones(1, size(S.allFeature,3)); % fallback: unweighted
            end

            cache.(percept).(validity){i} = struct( ...
                't', S.t, ...
                'SubjectName', {S.SubjectName}, ...
                'subjMean', subjMean, ...
                'nTrials', nTrials);
        end
    end
end

%% ================= FIGURE 1: averaged across validity =================

figure('Color','w','Position',[100 50 800 1200]);

for i = 1:numel(conds)
    n = conds(i);
    subplot(numel(conds),1,i);
    hold on

    h1 = plotAvgAcrossValidity(cache, 'two', validities, i, 'r');
    h2 = plotAvgAcrossValidity(cache, 'one', validities, i, 'b');

    addOnsetLines(n);
    xlim([-0.1 0.4]);
    title(sprintf('ISI %d ms', n*7));
    ylabel('Amplitude (\muV)');
    if i == numel(conds), xlabel('Time (s)'); end
    grid on; box off

    lgd = legend([h1 h2], {'Perceived 2 flashes','Perceived 1 flash'});
    lgd.Position = [0.35 0.005 0.3 0.02];
    lgd.Orientation = 'horizontal';
    lgd.Box = 'off';
end

sgtitle(sprintf('First flash locked ERP (%s, %d-%d Hz)', ...
    chanLabel, band(1), band(2)), 'FontSize',16, 'FontWeight','bold');

%% ================= FIGURE 2: per-validity (color=validity, style=one/two) ==

validityColors = containers.Map( ...
    {'valid','neutral','invalid'}, ...
    { [0.55 0 0], [0 0 0], [0 0 0.55] } );   % dark red, black, dark blue
styleTwo = '-';
styleOne = '--';

figure('Color','w','Position',[100 50 900 1200]);
allHandles = [];
allLabels  = {};

for i = 1:numel(conds)
    n = conds(i);
    subplot(numel(conds),1,i);
    hold on

    for iV = 1:numel(validities)
        validity = validities{iV};
        vColor = validityColors(validity);

        S1 = cache.two.(validity){i};
        if ~isempty(S1)
            [m, se] = subjectMeanSE(S1.subjMean);
            h = plotShaded(S1.t, m, se, vColor, styleTwo, 1.8, 0.1);
            if i == 1
                allHandles(end+1) = h; %#ok<SAGROW>
                allLabels{end+1} = sprintf('2 flashes - %s', validity); %#ok<SAGROW>
            end
        end

        S2 = cache.one.(validity){i};
        if ~isempty(S2)
            [m, se] = subjectMeanSE(S2.subjMean);
            h = plotShaded(S2.t, m, se, vColor, styleOne, 1.8, 0.1);
            if i == 1
                allHandles(end+1) = h; %#ok<SAGROW>
                allLabels{end+1} = sprintf('1 flash - %s', validity); %#ok<SAGROW>
            end
        end
    end

    addOnsetLines(n);
    xlim([-0.1 0.4]);
    title(sprintf('ISI %d ms', n*7));
    ylabel('Amplitude (\muV)');
    if i == numel(conds), xlabel('Time (s)'); end
    grid on; box off
end

lgd = legend(allHandles, allLabels, 'Orientation','horizontal', 'NumColumns', 3);
lgd.Position = [0.15 0.005 0.7 0.03];
lgd.Box = 'off';

sgtitle(sprintf('First flash locked ERP (%s, %d-%d Hz)', ...
    chanLabel, band(1), band(2)), 'FontSize',16, 'FontWeight','bold');

%% ================= FIGURE 3: aggregated across all ISIs =================

cols.valid   = [0 0.7 0];
cols.neutral = [0.5 0.5 0.5];
cols.invalid = [0.85 0 0];

figure('Color','w');
hold on
h = gobjects(0);
labels = {};

for p = 1:numel(percepts)
    percept = percepts{p};
    ls = '-'; if strcmp(percept,'one'), ls = '--'; end

    for j = 1:numel(validities)
        cue = validities{j};
        c = cols.(cue);

        entries = cache.(percept).(cue);
        valid_i = ~cellfun(@isempty, entries);
        if ~any(valid_i), continue; end
        entries = entries(valid_i);

        subjPooled = pooledSubjectMeans(entries);  % T x Nsub, trial-weighted across ISI, per subject
        if isempty(subjPooled), continue; end

        tRef = entries{1}.t;
        [meanWave, seWave] = subjectMeanSE(subjPooled);

        hLine = plotShaded(tRef, meanWave, seWave, c, ls, 2.5, 0.12);
        h(end+1) = hLine; %#ok<SAGROW>
        labels{end+1} = sprintf('%s %s', [upper(percept(1)) percept(2:end)], cue); %#ok<SAGROW>
    end
end

xline(0,'--k','LineWidth',1.5,'HandleVisibility','off');
xlabel('Time (s)');
ylabel('Amplitude (\muV)');
legend(h, labels, 'Location','eastoutside');
title(sprintf('Aggregated Across ISIs (%s)', chanLabel));
grid on; box off


%% ================= FIGURE 4: averaged across validity AND aggregated across ISI =================

figure('Color','w','Position',[100 50 700 500]);
hold on

h1 = plotAvgAcrossValidityAndISI(cache, 'two', validities, numel(conds), 'r');
h2 = plotAvgAcrossValidityAndISI(cache, 'one', validities, numel(conds), 'b');

xline(0,'--k','LineWidth',1.5,'HandleVisibility','off');
xlim([-0.1 0.4]);
xlabel('Time (s)');
ylabel('Amplitude (\muV)');
grid on; box off

legend([h1 h2], {'Perceived 2 flashes','Perceived 1 flash'}, 'Location','best');

title(sprintf('First flash locked ERP (%s, %d-%d Hz)', ...
    chanLabel, band(1), band(2)));

%% ================= FIGURE 5: grand average by validity only =================
% Pools across BOTH percept (one/two) AND all ISI conditions, leaving only
% validity as the grouping factor. One line per validity.

figure('Color','w','Position',[100 50 700 500]);
hold on
h = gobjects(0);
labels = {};

for j = 1:numel(validities)
    cue = validities{j};
    c = cols.(cue);

    entries = {};
    for p = 1:numel(percepts)
        percept = percepts{p};
        for i = 1:numel(conds)
            s = cache.(percept).(cue){i};
            if ~isempty(s)
                entries{end+1} = s; %#ok<AGROW>
            end
        end
    end

    if isempty(entries), continue; end

    subjPooled = pooledSubjectMeans(entries);
    if isempty(subjPooled), continue; end

    tRef = entries{1}.t;
    [meanWave, seWave] = subjectMeanSE(subjPooled);

    hLine = plotShaded(tRef, meanWave, seWave, c, '-', 2.5, 0.15);
    h(end+1) = hLine; %#ok<SAGROW>
    labels{end+1} = cue; %#ok<SAGROW>
end

xline(0,'--k','LineWidth',1.5,'HandleVisibility','off');
xlabel('Time (s)');
ylabel('Amplitude (\muV)');
legend(h, labels, 'Location','best');
title(sprintf('Grand Average by Validity (%s, %d-%d Hz)', ...
    chanLabel, band(1), band(2)));
grid on; box off

%% ================= LOCAL HELPER FUNCTIONS =================

function subjPooled = pooledSubjectMeans(entries)
% entries: cell array of cache structs (each has .SubjectName, .subjMean
% [T x Nsub], .nTrials [1 x Nsub]) for the SAME percept/validity across
% different ISI conditions (or the same ISI across different validities).
%
% For each subject present in ANY of the entries, computes a
% trial-count-weighted average across the entries (conditions),
% using only the entries where that subject is actually present.
% Subjects missing from some conditions are averaged over the
% conditions they DO have (partial pooling).

    if isempty(entries)
        subjPooled = [];
        return;
    end

    T = size(entries{1}.subjMean, 1);

    allNames = {};
    for k = 1:numel(entries)
        allNames = union(allNames, entries{k}.SubjectName);
    end
    nSub = numel(allNames);
    subjPooled = nan(T, nSub);

    for si = 1:nSub
        name = allNames{si};
        wSum = 0;
        acc  = zeros(T,1);
        for k = 1:numel(entries)
            e = entries{k};
            idx = find(strcmp(e.SubjectName, name), 1);
            if isempty(idx), continue; end
            w = e.nTrials(idx);
            if w <= 0, continue; end
            acc = acc + w * e.subjMean(:,idx);
            wSum = wSum + w;
        end
        if wSum > 0
            subjPooled(:,si) = acc / wSum;
        end
    end

    keep = ~all(isnan(subjPooled), 1);
    subjPooled = subjPooled(:, keep);
end

function [m, se] = subjectMeanSE(subjMean)
% subjMean: T x Nsub. Returns across-subject mean and SE (subject
% variation only), omitting subjects with NaN at a given time sample.
    m  = mean(subjMean, 2, 'omitnan');
    n  = sum(~isnan(subjMean), 2);
    sd = std(subjMean, 0, 2, 'omitnan');
    se = sd ./ sqrt(max(n,1));
    se(n < 2) = NaN; % SE undefined with <2 subjects
end

function h = plotAvgAcrossValidityAndISI(cache, percept, validities, nConds, color)
    entries = {};
    for iV = 1:numel(validities)
        v = validities{iV};
        for i = 1:nConds
            s = cache.(percept).(v){i};
            if ~isempty(s)
                entries{end+1} = s; %#ok<AGROW>
            end
        end
    end

    if isempty(entries)
        h = [];
        return;
    end

    t = entries{1}.t;
    subjPooled = pooledSubjectMeans(entries);
    if isempty(subjPooled)
        h = [];
        return;
    end

    [m, se] = subjectMeanSE(subjPooled);
    h = plotShaded(t, m, se, color, '-', 2, 0.2);
end

function h = plotShaded(t, meanWave, seWave, color, lineStyle, lineWidth, faceAlpha)
% Draws a shaded SE band + mean line; returns line handle for legend use.
    fill([t fliplr(t)], ...
         [(meanWave-seWave)' fliplr((meanWave+seWave)')], ...
         color, 'FaceAlpha', faceAlpha, 'EdgeColor','none', 'HandleVisibility','off');
    h = plot(t, meanWave, 'Color', color, 'LineStyle', lineStyle, 'LineWidth', lineWidth);
end

function h = plotAvgAcrossValidity(cache, percept, validities, condIdx, color)
    entries = cellfun(@(v) cache.(percept).(v){condIdx}, validities, 'UniformOutput', false);
    valid_i = ~cellfun(@isempty, entries);
    if ~any(valid_i)
        h = [];
        return;
    end
    entries = entries(valid_i);

    t = entries{1}.t;
    subjPooled = pooledSubjectMeans(entries);
    if isempty(subjPooled)
        h = [];
        return;
    end

    [m, se] = subjectMeanSE(subjPooled);
    h = plotShaded(t, m, se, color, '-', 2, 0.2);
end

function addOnsetLines(n)
    x = xline(0,'--k','LineWidth',1.5);
    x.Annotation.LegendInformation.IconDisplayStyle = 'off';

    isiSec = n * 7e-3;
    x2 = xline(isiSec,'--k','LineWidth',1.5);
    x2.Annotation.LegendInformation.IconDisplayStyle = 'off';
end