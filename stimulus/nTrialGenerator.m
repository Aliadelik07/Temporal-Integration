clear; clc;

%% PARAMETERS
ISIframes_levels = [1 3 5 7 9];
dtcolor_levels = [64 100 128 191 255]; 

%% ---------------- Base design (cueType + flashSide) ----------------
cueType = [];
flashSide = [];

% LEFT cues (4 left, 1 right)
cueType   = [cueType; repmat("left",5,1)];
flashSide = [flashSide; ["left";"left";"left";"left";"right"]];

% RIGHT cues (4 right, 1 left)
cueType   = [cueType; repmat("right",5,1)];
flashSide = [flashSide; ["right";"right";"right";"right";"left"]];

% NEUTRAL cues (2 left, 2 right)
cueType   = [cueType; repmat("neutral",4,1)];
flashSide = [flashSide; ["left";"left";"right";"right"]];

baseTrials = table(cueType, flashSide);

%% ---------------- FULL FACTORIAL ----------------
trialList = [];

for i = 1:length(ISIframes_levels)
    for j = 1:length(dtcolor_levels)
        temp = baseTrials;
        temp.ISIframes = repmat(ISIframes_levels(i), height(baseTrials), 1);
        temp.dtcolor   = repmat(dtcolor_levels(j), height(baseTrials), 1);
        trialList = [trialList; temp];
    end
end

%% ---------------- Cue Validity ----------------
trialList.CueValidity = repmat("invalid", height(trialList), 1);
trialList.CueValidity(trialList.cueType == trialList.flashSide) = "valid";
trialList.CueValidity(trialList.cueType == "neutral") = "neutral";

%% ---------------- BALANCED PROBE ----------------
trialList.probe = strings(height(trialList),1);

rng('shuffle');

validityLevels = unique(trialList.CueValidity);
ISIlevels = unique(trialList.ISIframes);
colorLevels = unique(trialList.dtcolor);

for v = 1:length(validityLevels)
    for i = 1:length(ISIlevels)
        for c = 1:length(colorLevels)

            idx = find( trialList.CueValidity == validityLevels(v) & ...
                        trialList.ISIframes == ISIlevels(i) & ...
                        trialList.dtcolor == colorLevels(c) );

            n = length(idx);
            if n == 0
                continue;
            end

            nHalf = floor(n/2);

            tempProbe = [repmat("top", nHalf, 1); ...
                         repmat("bottom", n - nHalf, 1)];

            % shuffle within this cell
            tempProbe = tempProbe(randperm(n));

            trialList.probe(idx) = tempProbe;
        end
    end
end

%% ---------------- ADD ISI = 0 BALANCED TRIALS ----------------

ISI0_trials = [];

validityLevels = ["valid","invalid","neutral"];
colorLevels = dtcolor_levels;
probeLevels = ["top","bottom"];

for v = 1:length(validityLevels)
    for c = 1:length(colorLevels)
        for p = 1:length(probeLevels)

            % Find matching trials from existing pool
            idx = find(trialList.CueValidity == validityLevels(v) & ...
                       trialList.dtcolor == colorLevels(c));

            % randomly pick ONE trial structure
            chosen = idx(randi(length(idx)));

            temp = trialList(chosen,:);

            % overwrite key fields
            temp.ISIframes = 0;
            temp.probe = probeLevels(p);

            ISI0_trials = [ISI0_trials; temp];
        end
    end
end

%% Shuffle ISI=0 trials
ISI0_trials = ISI0_trials(randperm(height(ISI0_trials)), :);

%% Append to main trial list
trialList = [trialList; ISI0_trials];

%% ---------------- FINAL RANDOMIZATION ----------------
trialList = trialList(randperm(height(trialList)), :);

%% ---------------- CHECKS ----------------
disp('First 10 trials:')
head(trialList,10)

disp(['Total trials: ' num2str(height(trialList))]);

%% ---------------- HISTOGRAM CHECKS ----------------

figure;

%% 1. Overall balance
subplot(2,2,1)
counts = groupcounts(trialList.probe);
bar(counts)
set(gca,'XTickLabel',categories(categorical(trialList.probe)))
title('Overall Probe Balance')

%% 2. CueValidity × Probe
subplot(2,2,2)
counts_validity = groupcounts(trialList, ["CueValidity","probe"]);

cv = categories(categorical(trialList.CueValidity));
pb = categories(categorical(trialList.probe));

mat = zeros(length(cv), length(pb));

for i = 1:height(counts_validity)
    r = find(cv == counts_validity.CueValidity(i));
    c = find(pb == counts_validity.probe(i));
    mat(r,c) = counts_validity.GroupCount(i);
end

bar(mat)
set(gca,'XTickLabel',cv)
legend(pb)
title('Probe within CueValidity')

%% 3. ISI × Probe
subplot(2,2,3)
counts_ISI = groupcounts(trialList, ["ISIframes","probe"]);

isi = unique(trialList.ISIframes);
pb = categories(categorical(trialList.probe));

mat = zeros(length(isi), length(pb));

for i = 1:height(counts_ISI)
    r = find(isi == counts_ISI.ISIframes(i));
    c = find(pb == counts_ISI.probe(i));
    mat(r,c) = counts_ISI.GroupCount(i);
end

bar(mat)
set(gca,'XTickLabel',isi)
legend(pb)
title('Probe within ISI')

%% 4. Color × Probe
subplot(2,2,4)
counts_color = groupcounts(trialList, ["dtcolor","probe"]);

col = unique(trialList.dtcolor);
pb = categories(categorical(trialList.probe));

mat = zeros(length(col), length(pb));

for i = 1:height(counts_color)
    r = find(col == counts_color.dtcolor(i));
    c = find(pb == counts_color.probe(i));
    mat(r,c) = counts_color.GroupCount(i);
end

bar(mat)
set(gca,'XTickLabel',col)
legend(pb)
title('Probe within Color')

%% ---------------- SAVE ----------------
save('/Users/ali/Documents/Experiment/Analysis_TIW/trialList.mat', 'trialList');

% Set random seed (optional, for reproducibility)
rng('shuffle'); % or use a fixed number like rng(1)

% Extract selected rows
trialList = trialList(randperm(size(trialList, 1), 10), :);

% Save to .mat file
save('/Users/ali/Documents/Experiment/Analysis_TIW/trialListIntro.mat', 'trialList');