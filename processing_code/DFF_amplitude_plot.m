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
band = [30 90];

% ---- Channels to average ----
% chanSel   = {'PO7','PO3','POz','O1','Oz','POz','O2','PO4','PO8'}; chanLabel = 'Occipital';
% chanSel   = {'O2','PO4','PO8'}; chanLabel = 'Occipital Right';
% chanSel   = {'PO7','PO3','O1'}; chanLabel = 'Occipital Left';
chanSel   = {'PO7','PO3','O1','O2','PO4','PO8'}; chanLabel = 'Laterized Occipital';

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

% ---- Preload every data file exactly once into a cache ----
% cache.(percept).(validity){condIdx} = loaded struct (or [] if missing)
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
            if exist(fpath,'file')
                cache.(percept).(validity){i} = load(fpath);
            else
                cache.(percept).(validity){i} = [];
            end
        end
    end
end

%% ================= FIGURE 1: averaged across validity =================

figure('Color','w','Position',[100 50 800 1200]);

for i = 1:numel(conds)
    n = conds(i);
    subplot(numel(conds),1,i);
    hold on

    h1 = plotAvgAcrossValidity(cache, 'two', validities, i, ch, 'r');
    h2 = plotAvgAcrossValidity(cache, 'one', validities, i, ch, 'b');

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
            h = plotShaded(S1.t, chanAvg(S1.MeanAmp,ch), chanAvg(S1.CI95,ch), ...
                vColor, styleTwo, 1.8, 0.1);
            if i == 1
                allHandles(end+1) = h; %#ok<SAGROW>
                allLabels{end+1} = sprintf('2 flashes - %s', validity); %#ok<SAGROW>
            end
        end

        S2 = cache.one.(validity){i};
        if ~isempty(S2)
            h = plotShaded(S2.t, chanAvg(S2.MeanAmp,ch), chanAvg(S2.CI95,ch), ...
                vColor, styleOne, 1.8, 0.1);
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

        % Gather non-empty entries across conditions from cache (no re-loading)
        entries = cache.(percept).(cue);
        valid_i = ~cellfun(@isempty, entries);
        if ~any(valid_i), continue; end

        allMean = cell2mat(cellfun(@(s) chanAvg(s.MeanAmp,ch), entries(valid_i), 'UniformOutput', false));
        allCI   = cell2mat(cellfun(@(s) chanAvg(s.CI95,ch),   entries(valid_i), 'UniformOutput', false));
        tRef    = entries{find(valid_i,1)}.t;

        meanWave = mean(allMean, 2, 'omitnan');
        ciWave   = mean(allCI, 2, 'omitnan');

        hLine = plotShaded(tRef, meanWave, ciWave, c, ls, 2.5, 0.12);
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

h1 = plotAvgAcrossValidityAndISI(cache, 'two', validities, numel(conds), ch, 'r');
h2 = plotAvgAcrossValidityAndISI(cache, 'one', validities, numel(conds), ch, 'b');

xline(0,'--k','LineWidth',1.5,'HandleVisibility','off');
xlim([-0.1 0.4]);
xlabel('Time (s)');
ylabel('Amplitude (\muV)');
grid on; box off

legend([h1 h2], {'Perceived 2 flashes','Perceived 1 flash'}, 'Location','best');

title(sprintf('First flash locked ERP (%s, %d-%d Hz)', ...
    chanLabel, band(1), band(2)));

%% ================= LOCAL HELPER FUNCTIONS =================

function y = chanAvg(M, ch)
% Collapse the selected channels into a single waveform by averaging.
% M is [nTime x nChannels]; ch is a vector of column indices.
    y = mean(M(:,ch), 2, 'omitnan');
end

function h = plotAvgAcrossValidityAndISI(cache, percept, validities, nConds, ch, color)
% Averages MeanAmp/CI95 across BOTH validities and all ISI conditions
% from the preloaded cache, then plots the shaded mean.
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
    meanCells = cellfun(@(s) chanAvg(s.MeanAmp,ch), entries, 'UniformOutput', false);
    ciCells   = cellfun(@(s) chanAvg(s.CI95,ch),   entries, 'UniformOutput', false);
    meanStack = cat(3, meanCells{:});
    ciStack   = cat(3, ciCells{:});

    meanAvg = mean(meanStack, 3);
    ciAvg   = mean(ciStack, 3);

    h = plotShaded(t, meanAvg, ciAvg, color, '-', 2, 0.2);
end

function h = plotShaded(t, meanWave, ciWave, color, lineStyle, lineWidth, faceAlpha)
% Draws a shaded CI band + mean line; returns line handle for legend use.
    fill([t fliplr(t)], ...
         [(meanWave-ciWave)' fliplr((meanWave+ciWave)')], ...
         color, 'FaceAlpha', faceAlpha, 'EdgeColor','none', 'HandleVisibility','off');
    h = plot(t, meanWave, 'Color', color, 'LineStyle', lineStyle, 'LineWidth', lineWidth);
end

function h = plotAvgAcrossValidity(cache, percept, validities, condIdx, ch, color)
% Averages MeanAmp/CI95 across validities (for a given condition index) from
% the preloaded cache, then plots the shaded mean. Returns [] if no data.
    entries = cellfun(@(v) cache.(percept).(v){condIdx}, validities, 'UniformOutput', false);
    valid_i = ~cellfun(@isempty, entries);
    if ~any(valid_i)
        h = [];
        return;
    end
    entries = entries(valid_i);

    t = entries{1}.t;
    meanCells = cellfun(@(s) chanAvg(s.MeanAmp,ch), entries, 'UniformOutput', false);
    ciCells   = cellfun(@(s) chanAvg(s.CI95,ch),   entries, 'UniformOutput', false);
    meanStack = cat(3, meanCells{:});
    ciStack   = cat(3, ciCells{:});

    meanAvg = mean(meanStack, 3);
    ciAvg   = mean(ciStack, 3);

    h = plotShaded(t, meanAvg, ciAvg, color, '-', 2, 0.2);
end

function addOnsetLines(n)
% Draws the two vertical onset lines (first flash at 0, second flash at ISI).
    x = xline(0,'--k','LineWidth',1.5);
    x.Annotation.LegendInformation.IconDisplayStyle = 'off';

    isiSec = n * 7e-3;
    x2 = xline(isiSec,'--k','LineWidth',1.5);
    x2.Annotation.LegendInformation.IconDisplayStyle = 'off';
end