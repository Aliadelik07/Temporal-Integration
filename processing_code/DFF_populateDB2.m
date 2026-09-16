function [] = DFF_populateDB2()
% ========================================================================
% This file is part of DFF project
% 
% Free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This code is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
%
% ========================================================================
% This software was developed by
%       Adeli-Koudehi Ali (Lorraine University)
% ------------------------------------------------------------------------
%
% DESCRIPTION : 
%   Function aims to populate a brainstorm database from a directory
%   containging one folder per participant (name of the folder will be used
%   as the name of the subject). (Brainstorm must be up and running at exec)


% Input directory 
INDIR = "D:\DFF_data";
BrainstormDbDir = "D:\Brainstorm_db";
ProtocolName ='DFF_11092026'; 

% Reads all folders that are in INDIR 
d = dir(INDIR); 
isub = [d(:).isdir]; % returns logical vector if is folder
subjects = {d(isub).name}';
subjects(ismember(subjects,{'.','..'})) = []; % Removes . and ..

if isempty(subjects)    
    fprintf(sprintf('\n WARNING : NO DATA to process in %s\n',INDIR));
    return;
end


if ~brainstorm('status')
    brainstorm 
end

% Disable auto-update
bst_set('AutoUpdates',  0);

% Test if database exist otherwise promtp error
if ~exist(BrainstormDbDir ,'dir')
    fprintf('Creating your database %s\n',BrainstormDbDir); 
    mkdir(BrainstormDbDir);
end
 
% Set the Brainstorm DB folder
bst_set('BrainstormDbDir', BrainstormDbDir);

% Get the protocol index of an existing protocol 
iProtocol = bst_get('Protocol', ProtocolName);

% Create a new protocol if needed
if isempty(iProtocol)
    gui_brainstorm('CreateProtocol', ProtocolName, 0, 0); 
else
    bst_set('iProtocol', iProtocol)
end

% Checklist online (alternative : DFF_checklist.CSV offline)
sheetID = '1PIjK_Jn5VKEFoBmR4rp5FlIW5eDi8ez75pUIfoF3Lyw';
url = sprintf( ...
    'https://docs.google.com/spreadsheets/d/%s/export?format=csv', ...
    sheetID);

T_check = readtable(url);

T_check = T_check(~strcmpi(strtrim(string(T_check.EEG)), "x"), :);
subjects = T_check.sub;


% Loop through all subjects
for iSubj=1:length(subjects)
     

    % Prepare EEG file name 
    fname_run= dir(fullfile(INDIR,subjects{iSubj},strcat(subjects{iSubj},'*.bdf')));
      
     % Check if the file run (.bdf) exist
    if isempty(fname_run)
        fprintf('File not found %s\n',fullfile(INDIR,subjects{iSubj},strcat(subjects{iSubj},'*.bdf')));
        continue;
    end

    % Setting infos
    RefChannels = strtrim(strsplit(T_check.ref_chan{iSubj}, ',')); RefChannels = RefChannels(~cellfun(@isempty, RefChannels));
    BadChannels = strtrim(strsplit(T_check.bad_chan{iSubj}, ',')); BadChannels = BadChannels(~cellfun(@isempty, BadChannels));
    BadICAcomponents = strtrim(strsplit(T_check.ICA_proj{iSubj}, ',')); BadICAcomponents = BadICAcomponents(~cellfun(@isempty, BadICAcomponents));

    % Get BAD event file
    fname = dir(fullfile(INDIR,subjects{iSubj},strcat('BAD_event.eve'))); 
    BADevent = fullfile(fname.folder,fname.name);

    % Get raw file pathname 
    RawFile = fullfile(INDIR,subjects{iSubj},fname_run.name ); 

    % Input files
        sFiles = [];
        
        % Start a new report
        bst_report('Start', sFiles);
        
        %  Create subject if it does not exist 
        if isempty(bst_get('Subject', subjects{iSubj}, 1))
            % Creates a subject in database using the dfault anatomy and default
            % channels
            [~, ~] = db_add_subject(subjects{iSubj}, [], 1, 0);
            panel_protocols('UpdateTree'); % Update the Protocol in GUI
        end 
         
        % Process: Create link to raw file
        sFiles = bst_process('CallProcess', 'process_import_data_raw', sFiles, [], ...
            'subjectname',    subjects{iSubj}, ...
            'datafile',       {RawFile, 'EEG-BDF'}, ...
            'channelreplace', 1, ...
            'channelalign',   1, ...
            'evtmode',        'value');
        
        % Process: Add EEG positions
        sFiles = bst_process('CallProcess', 'process_channel_addloc', sFiles, [], ...
            'channelfile', {'', ''}, ...
            'usedefault',  'ICBM152: BioSemi 64 10-10', ...  % ICBM152: BioSemi 64 10-10
            'fixunits',    1, ...
            'vox2ras',     0, ...
            'mrifile',     {'', ''}, ...
            'fiducials',   []);

        % Mark bad channels
        BadChannels = BadChannels(~cellfun(@isempty, BadChannels));
        
        if ~isempty(BadChannels)
            sensorStr = strjoin(BadChannels, ', ');
            chan_sFiles = bst_process('CallProcess', 'process_channel_setbad', sFiles, [], ...
                'sensortypes', sensorStr);
        else
            fprintf('No bad channels specified ------- No global BAD channels\n');
        end
        
        % Re-Reference the signals
        RefChannels = RefChannels(~cellfun(@isempty, RefChannels));

        if ~isempty(RefChannels)
            ref_chans = strjoin(RefChannels, ', ');
            ref_sFiles = bst_process('CallProcess', 'process_eegref', sFiles, [], ...
                'eegref',      ref_chans, ...
                'sensortypes', 'EEG');
        else
            fprintf('No reference channels specified ------- No re-referencing applied\n');
        end
        
        %% Photocell detection and events
        % Process: Detect: stim1
        sFilesEvent = bst_process('CallProcess', 'process_evt_detect_analog', sFiles, [], ...
            'eventname',   'stim2', ...
            'channelname', 'Erg1', ...
            'timewindow',  [], ...
            'threshold',   2, ...
            'blanking',    1, ...
            'highpass',    0, ...
            'lowpass',     0, ...
            'refevent',    '200', ...
            'isfalling',   0, ...
            'ispullup',    0, ...
            'isclassify',  0);

        % Process: Detect: stim1
        sFilesEvent = bst_process('CallProcess', 'process_evt_detect_analog', sFilesEvent, [], ...
            'eventname',   'stim11', ...
            'channelname', 'Erg1', ...
            'timewindow',  [], ...
            'threshold',   2, ...
            'blanking',    1, ...
            'highpass',    0, ...
            'lowpass',     0, ...
            'refevent',    '110', ...
            'isfalling',   0, ...
            'ispullup',    0, ...
            'isclassify',  0);

        % Process: Detect: stim1
        sFilesEvent = bst_process('CallProcess', 'process_evt_detect_analog', sFilesEvent, [], ...
            'eventname',   'stim12', ...
            'channelname', 'Erg1', ...
            'timewindow',  [], ...
            'threshold',   2, ...
            'blanking',    1, ...
            'highpass',    0, ...
            'lowpass',     0, ...
            'refevent',    '120', ...
            'isfalling',   0, ...
            'ispullup',    0, ...
            'isclassify',  0);

        % Process: Duplicate / merge events
        sFilesEvent = bst_process('CallProcess', 'process_evt_merge', sFilesEvent, [], ...
            'evtnames', 'stim11,stim12', ...
            'newname',  'stim1', ...
            'delete',   1);

         % Process: Duplicate / merge events
        sFilesEvent = bst_process('CallProcess', 'process_evt_merge', sFilesEvent, [], ...
            'evtnames', '10,20,30', ...
            'newname',  'cue', ...
            'delete',   1);
        
         % Process: Duplicate / merge events
        sFilesEvent = bst_process('CallProcess', 'process_evt_merge', sFilesEvent, [], ...
            'evtnames', '15', ...
            'newname',  'resp', ...
            'delete',   1);
        
        % Process: Delete events
        sFilesEvent = bst_process('CallProcess', 'process_evt_delete', sFilesEvent, [], ...
            'eventname', '110,120,200');
    
        %% individual cases
        if ismember(subjects{iSubj}, 'subSH')
            sFilesEvent = bst_process('CallProcess', 'process_evt_delete', sFilesEvent, [], ...
                'eventname', 'resp');

        elseif ismember(subjects{iSubj}, 'subBE')
            fprintf('Pausing for subject %s — remove triggers around 2355s manually\n', subjects{iSubj});
            pause

        elseif ismember(subjects{iSubj}, 'subTH')
            fprintf('Pausing for subject %s — remove triggers around 32s manually\n', subjects{iSubj});
            pause
        end

        %%  Adding trial identity to trigger
        % -------------- importing trialList --------------
        filePath = fullfile('D:\DFF_data', subjects{iSubj}, subjects{iSubj} + ".csv");
        
        T = readtable(filePath);
        
        T = varfun(@string, T);
        
        T.RespProbe = string(T{:,10} == T{:,5});
        
        % all variation epochs
        T.identity = string(T{:,4}) + "_" + ...
                      string(T{:,3}) + "_" + ...
                      string(T{:,6}) + "_" + ...
                      string(T{:,7}) + "_" + ...
                      string(T{:,9}) + "_" + ...
                      string(T{:,13});
        
        
        
        % -------------- creating new events --------------
        % Load data structure 
        sRaw = in_bst_data(sFiles.FileName, 'F');

        eventNames = {'cue','stim1','resp'};
        for e = 1:numel(eventNames)
        
            % ---- extract event ----
            evtnew = sRaw.F.events(find(strcmp({sRaw.F.events.label}, eventNames{e}), 1));
        
            if isempty(evtnew)
                warning('Event %s not found', eventNames{e});
                continue
            end
        
            tnew  = evtnew.times;
            epnew = evtnew.epochs;
        
            % ---- choose grouping variable ----
            if eventNames{e} == "cue"
                groupingVar = string(T{:,4});
            elseif eventNames{e} == "stim1"
                groupingVar = string(T{:,9}) + "_" + string(T{:,6})+ "_" + string(T{:,4});
            elseif eventNames{e} == "stim2"
                groupingVar =string(T{:,9}) + "_" + string(T{:,6})+ "_" + string(T{:,4});
            elseif eventNames{e} == "resp"
                groupingVar = string(T{:,9}) + "_" + string(T{:,13});
            end
        
            % ---- group ----
            [ulabels, ~, idx] = unique(groupingVar, 'stable');
        
            newEvents = repmat(evtnew, 1, numel(ulabels));
        
            for i = 1:numel(ulabels)
                sel = idx == i;
        
                newEvents(i).label  = char(eventNames{e} + "_" + ulabels(i));
                newEvents(i).times  = tnew(sel);
                newEvents(i).epochs = epnew(sel);
            end
        
            % append ----
            sRaw.F.events = [sRaw.F.events, newEvents];
        
        end
        
        % Save the events
        bst_save(file_fullpath(sFiles.FileName), sRaw, 'v6', 1);
        
        % loading BAD events
        % Process: Import from file
        sFiles = bst_process('CallProcess', 'process_evt_import', sFiles, [], ...
            'evtfile', {BADevent, 'ARRAY-SAMPLES'}, ...
            'evtname', 'BAD', ...
            'delete',  0);

         % Process: Band-pass:0.25Hz-95Hz
        sFiles = bst_process('CallProcess', 'process_bandpass', sFiles, [], ...
            'sensortypes', '', ...
            'highpass',    0.25, ...
            'lowpass',     95, ...
            'tranband',    0, ...
            'attenuation', 'strict', ...  % 60dB
            'ver',         '2019', ...  % 2019
            'mirror',      0, ...
            'read_all',    0);

        % Process: Notch filter: 50Hz
        sFiles = bst_process('CallProcess', 'process_notch', sFiles, [], ...
            'sensortypes', '', ...
            'freqlist',    50, ...
            'cutoffW',     5, ...
            'useold',      0, ...   
            'read_all',    0);

        
        % Remove ICA components if needed 
        if ~isempty(BadICAcomponents)

            % Get ICA projectors file 
            fname = dir(fullfile(INDIR,subjects{iSubj},'proj_ica.mat')); 
            ICAprojectors = fullfile(fname.folder,fname.name); 
            projectors = load(ICAprojectors); 

            BadICAcomponents = BadICAcomponents(~cellfun(@isempty, BadICAcomponents));

            % Select ICA (picard) projector
            ica_proj = projectors.Projector(contains({projectors.Projector.Comment},'ICA_picard')); 

            % Reads the ICA components to reject 
            idx_to_reject = str2double(BadICAcomponents);

            % Get projector wich has 64 components (in case there are several tests with
            % various number of components we select the one that has 64
            for iIca=1:length(ica_proj)
            if size(ica_proj(iIca).Components,2)==32 ; ica_proj_nb = ica_proj(iIca); end
            end

            % Identify (flag) the components to remove
            ica_proj_nb.CompMask = zeros(length(ica_proj_nb.CompMask),1) ; 
            ica_proj_nb.CompMask(idx_to_reject) = 1 ;

            % Save projectors
            projectors.Projector = ica_proj_nb ; 

            % Append ICA projectors in the channel file 
            channelFile = bst_get('ChannelFileForStudy',  sFiles.FileName); 
            sChannel = in_bst_channel(channelFile);
            sChannel.Projector = [sChannel.Projector, projectors.Projector] ; 

            % Save channel file (will ICA projection apply automatically) 
            bst_save(file_fullpath(channelFile), sChannel, 'v7', 1);

        end

        % Process: Interpolate bad electrodes
        sFiles = bst_process('CallProcess', 'process_eeg_interpbad', sFiles, [], ...
            'maxdist',     5, ...
            'sensortypes', 'EEG');

%% ----------------- Epoching --------------------------------
% Process: Import MEG/EEG: Events
labels = {sRaw.F.events.label}; labels = string(labels);

mask = contains(labels, '_');
EventsMarkers = labels(mask);




% Loop through conditions 
    for iCond=1:length(EventsMarkers)

        if contains(EventsMarkers{iCond}, 'cue')
            Epoch = [-0.5,1.5];
            Epoch_baseline = [-0.5,0];
        else
            Epoch = [-0.5,0.5];
            Epoch_baseline = [-0.5,0];
        end

        %% -------------- ERP ----------------
            % Process: Import MEG/EEG: Events
            sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', ...
                sFiles, [], ...   
                'subjectname',   subjects{iSubj}, ...
                'condition',     EventsMarkers{iCond}, ...
                'eventname',     EventsMarkers{iCond}, ...
                'timewindow',    [], ...
                'epochtime',     Epoch, ...
                'split',         0, ...
                'createcond',    1, ...
                'ignoreshort',   1, ...
                'usectfcomp',    1, ...
                'usessp',        1, ...
                'freq',          [], ...
                'baseline',      Epoch_baseline, ...
                'blsensortypes', 'EEG');
            
             avg_sFilesEpochs = bst_process('CallProcess', 'process_average', sFilesEpochs, [], ...
                'avgtype',       1, ...  % Everything
                'avg_func',      1, ...  % Arithmetic average:  mean(x)
                'weighted',      1);

            %% -------------- PSD ----------------
            % PSD analysis
            PSDsFilesEpochs = bst_process('CallProcess', 'process_psd', sFilesEpochs, [], ...
                'timewindow',  Epoch, ...
                'win_length',  0.8, ...
                'win_overlap', 30, ...
                'units',       'physical', ...  % Physical: U2/Hz
                'sensortypes', 'EEG', ...
                'win_std',     0, ...
                'edit',        struct(...
                 'Comment',         'Avg,Power', ...
                 'TimeBands',       [], ...
                 'Freqs',           [], ...
                 'ClusterFuncTime', 'none', ...
                 'Measure',         'power', ...
                 'Output',          'average', ...
                 'SaveKernel',      0));

            % Process: Spectrum normalization
            PSDsFilesEpochsMultiply = bst_process('CallProcess', 'process_tf_norm', PSDsFilesEpochs, [], ...
                'normalize', 'multiply2020', ...  % 1/f compensation (multiply power by frequency)
                'overwrite', 0);

             %% -------------- TF ----------------
             if contains(EventsMarkers{iCond}, 'stim1')
            % Process: Time-frequency (Morlet wavelets)
            sFilesTF = bst_process('CallProcess', 'process_timefreq', sFilesEpochs, [], ...
                'sensortypes',   'EEG', ...
                'edit',          struct(...
                     'Comment',         'Avg,Power,1-90Hz', ...
                     'TimeBands',       [], ...
                     'Freqs',           [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90], ...
                     'MorletFc',        1, ...
                     'MorletFwhmTc',    3, ...
                     'ClusterFuncTime', 'none', ...
                     'Measure',         'power', ...
                     'Output',          'all ', ...
                     'RemoveEvoked',    0, ...
                     'SaveKernel',      0), ...
                'normalize2020', 1, ...
                'normalize',     'multiply2020');

            % Process: Z-score transformation: [-500ms,-2ms]
            sFilesTF_z = bst_process('CallProcess', 'process_baseline_norm', sFilesTF, [], ...
                'baseline',  Epoch_baseline, ...
                'method',    'zscore', ...  % Z-score transformation:    x_std = (x - &mu;) / &sigma;
                'overwrite', 0);

            % Process: Average: Everything
            sFilesTFavg = bst_process('CallProcess', 'process_average', sFilesTF_z, [], ...
                'avgtype',       1, ...  % Everything
                'avg_func',      1, ...  % Arithmetic average:  mean(x)
                'weighted',      1, ...
                'matchrows',     1, ...
                'iszerobad',     1);

             end

    end
end
end