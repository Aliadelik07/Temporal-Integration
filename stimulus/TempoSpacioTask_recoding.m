%% Visual two-flash fusion experiment with spatial probes
%% WITH EEG TRIGGERS + EYELINK

clear; clc;
Screen('Preference', 'SkipSyncTests', 1);

fname = 'sub00'; % file name
%% ================= EEG PARALLEL PORT =================
ioObj = io64;
status = io64(ioObj);

address = hex2dec('8FF8');  % port address

%% ---------------- INITIATION ----------------

expectedRefreshRate = 144;

cueFrames = round(1 * expectedRefreshRate);

flashFrames = 1;
ISIframes   = 1;
ITIframes   = round(1.0 * expectedRefreshRate);

eccentricityDeg = 10;
flashSizeDeg    = 2;

lineLengthPix = 9;
lineWidthPix  = 4;
lineSpacingPix = 5;

cueSize = 40;

bgcolor = 0;
flcolor = 255;
dtcolor = 0;

respFrames = round(10.0 * expectedRefreshRate);

devices = PsychHID('Devices');

keyboardIndices = [];
for i = 1:length(devices)
    if devices(i).usageValue == 6
        keyboardIndices(end+1) = i;
        fprintf('Keyboard %d: %s\n', i, devices(i).product);
    end
end

KbName('UnifyKeyNames');

keys = {'1!','2@','3#','4$'};
keyCodes = KbName(keys);

axisLength = 250;
quadSize   = 200;

trigger_fix = 13;
trigger_stim_one = 100;
trigger_stim_two = 200;
trigger_resp_start = 14;
trigger_resp_press = 15;

%% ---------------- SCREEN SETUP ----------------
screenNumber = 0;
[win, winRect] = Screen('OpenWindow', screenNumber, bgcolor);
Screen('TextSize', win, cueSize);

ifi = Screen('GetFlipInterval', win);
[xCenter, yCenter] = RectCenter(winRect);


%% ================= EYELINK INIT =================
if ~EyelinkInit()
    error('Eyelink Init aborted');
end

%Initilizing
el = EyelinkInitDefaults(win);
EyelinkInit();


%Opening a recording file
Eyelink('SetOfflineMode');
WaitSecs(0.5);
Eyelink('Openfile', fname);
Eyelink('Command','add_file_preamble_text "Two Flash Spatial Probe Experiment"');

% Enabling stimuli keyboard
Eyelink('Command','key_function space "accept_target_fixation"');
Eyelink('Command','key_function escape "exit_caliberation"');

%Set Up and Caliberation
EyelinkDoTrackerSetup(el);

%Recording
Eyelink('StartRecording');
WaitSecs(0.1);


% clear port
sendTrigger(ioObj,address,0) ;

%% ---------------- PHOTOCELL ----------------
[screenXpixels, screenYpixels] = Screen('WindowSize', win);

% Smaller rectangle dimensions
rectWidth = 100;   % width
rectHeight = 100;  % height

% Position on the right side
margin = 1;
left = screenXpixels - rectWidth - margin;
top = (screenYpixels / 2) - (rectHeight / 2);
right = left + rectWidth;
bottom = top + rectHeight;

cellRect = [left top right bottom];
%% ---------------- DEG → PIXELS ----------------
viewDistCm    = 80;
screenWidthCm = 52;

pixPerCm  = winRect(3) / screenWidthCm;
cmPerDeg  = 2 * viewDistCm * tan(pi / 360);
pixPerDeg = pixPerCm * cmPerDeg;

eccentricityPix = eccentricityDeg * pixPerDeg;
flashSizePix    = flashSizeDeg * pixPerDeg;

%% ---------------- FIXATION ----------------
fixSize = 10;
fixCoords = [-fixSize fixSize 0 0; 0 0 -fixSize fixSize];

fixMinFrames = round(0.6 * expectedRefreshRate);
fixMaxFrames = round(1 * expectedRefreshRate);

%% ================== MAIN LOOP ==================
% -------- LOAD trialList.csv --------
[scriptPath,~,~] = fileparts(mfilename('fullpath'));
load(fullfile(scriptPath, 'trialList.mat'));

nTrials = height(trialList);

data = table('Size',[nTrials 12], ...
    'VariableTypes',{'double','string','string','string','string','string','string',...
                    'double','string','string','double','double'}, ...
    'VariableNames',{'Trial','CueType','FlashSide','CueValidity','probe','ISIframes','dtcolor', ...
                     'Resp','RespFlash','ResProbe','RT','TrialTime'});

vbl = Screen('Flip', win);


% -------- First REST BREAK --------
    Screen('FillRect', win, bgcolor);
    DrawFormattedText(win, ...
            'Quand vous etes pret, appuyez sur une touche...', ...
            'center','center', flcolor);
    Screen('Flip', win);
        
    KbStrokeWait;   % wait for key press
        
    vbl = Screen('Flip', win); % reset flip timing

 % -------- LOOP START --------
for trial = 1:nTrials

    cueType   = trialList.cueType(trial);
    flashSide = trialList.flashSide(trial);
    ISIframes = trialList.ISIframes(trial);
    dtcolor   = trialList.dtcolor(trial);
    probe     = trialList.probe(trial);
    CueValidity= trialList.CueValidity(trial);
    
    if CueValidity == "valid"
        trigger_cue = 10;
    elseif CueValidity == "invalid"
        trigger_cue = 20;
    elseif CueValidity == "neutral"
        trigger_cue = 30;
    end
   
    resp = NaN;
    rt   = NaN;

    while isnan(resp)

    tic

    %% -------- FIXATION --------
    fixFrames = randi([fixMinFrames fixMaxFrames]);
    sendTrigger(ioObj,address,trigger_fix);

    for f = 1:fixFrames
        Screen('FillRect', win, bgcolor);
        Screen('DrawLines', win, fixCoords, 2, flcolor, [xCenter yCenter]);
        vbl = Screen('Flip', win, vbl + ifi);
    end

    %% -------- CUE --------
    if cueType == "left"
        cueSign = 'o';
    elseif cueType == "right"
        cueSign = '*';
    else
        cueSign = 'x';
    end

    sendTrigger(ioObj,address,trigger_cue);


    vbl = Screen('Flip', win);

    for f = 1:cueFrames
        Screen('FillRect', win, bgcolor);
        DrawFormattedText(win, cueSign, 'center', 'center', flcolor);
        vbl = Screen('Flip', win, vbl + 0.5 * ifi);
    end

    %% -------- FLASH SIDE --------
    if flashSide == "left"
        xPos = xCenter - eccentricityPix;
    else
        xPos = xCenter + eccentricityPix;
    end

    flashRect = CenterRectOnPointd([0 0 flashSizePix flashSizePix], xPos, yCenter);

    %% -------- PROBE POSITIONS --------
    xOffsets = [-2 -1 0 1 2] * lineSpacingPix;

    if probe == "top"
        lineCenterY = flashRect(2) + lineWidthPix; prob_trigger = 20;
    else
        lineCenterY = flashRect(4) - lineWidthPix; prob_trigger = 10;
    end

    lineCoords = [];
    for i = 1:length(xOffsets)
        xLine = xPos + xOffsets(i);
        thisLine = [
            xLine, xLine;
            lineCenterY - lineLengthPix/2, ...
            lineCenterY + lineLengthPix/2
        ];
        lineCoords = [lineCoords thisLine];
    end

    %% -------- FIRST FLASH --------
    sendTrigger(ioObj,address,trigger_stim_one+prob_trigger); % trigger first flash ISI and contrast

    Screen('FillRect', win, flcolor, flashRect); Screen('FillRect', win, flcolor, cellRect);
    Screen('DrawLines', win, lineCoords, lineWidthPix, dtcolor);
    
    
    vbl = Screen('Flip', win); 

    vbl = Screen('Flip', win, vbl + flashFrames * ifi);

    %% -------- ISI --------
    Screen('FillRect', win, bgcolor);
    vbl = Screen('Flip', win, vbl + ISIframes * ifi);

    %% -------- SECOND FLASH --------
    Screen('FillRect', win, flcolor, flashRect); Screen('FillRect', win, flcolor, cellRect);
    Screen('DrawLines', win, lineCoords, lineWidthPix, dtcolor);
    vbl = Screen('Flip', win);

    vbl = Screen('Flip', win, vbl + flashFrames * ifi);
    
    sendTrigger(ioObj,address, trigger_stim_two); % trigger second flash
    %% -------- RESPONSE PLACEHOLDER --------
    sendTrigger(ioObj,address,trigger_resp);
    % -------- FIXATION --------
    fixFrames = randi([fixMinFrames fixMaxFrames]);

    for f = 1:fixFrames
        Screen('FillRect', win, bgcolor);
        Screen('DrawLines', win, fixCoords, 2, flcolor, [xCenter yCenter]);
        vbl = Screen('Flip', win, vbl + ifi);
    end

    tStart = GetSecs;
    
    % Positions on the vertical axis
    yPos = linspace(yCenter-axisLength, yCenter+axisLength, 4);
    
    % Labels
    labels = {'2','1','-1','-2'};
    
    textX = xCenter + 40;
    
    circleRadius = 40;
    
    for f = 1:respFrames
        
        [keyIsDown, tKey, keyCode] = KbCheck;
        
        Screen('FillRect', win, bgcolor);
        
        % Draw vertical axis
        Screen('DrawLine', win, flcolor, xCenter, yCenter-axisLength, xCenter, yCenter+axisLength, 3);
        
        % Draw labels
        for i = 1:4
            DrawFormattedText(win, labels{i}, textX-10, yPos(i)+10, flcolor);
        end
        
        
        if keyIsDown
            
            if keyCode(keyCodes(1))
                resp = 1;
            elseif keyCode(keyCodes(2))
                resp = 2;
            elseif keyCode(keyCodes(3))
                resp = 3;
            elseif keyCode(keyCodes(4))
                resp = 4;
            end
            
            if ~isnan(resp)
                
                rt = tKey - tStart;
                
                % Circle around selected label
                circleRect = CenterRectOnPoint([0 0 circleRadius*2 circleRadius*2], ...
                                               textX, yPos(resp));
                
                Screen('FrameOval', win, flcolor, circleRect, 3);
                
                Screen('Flip', win);
                
                WaitSecs(0.2);
                break
            end
        end
        
        sendTrigger(ioObj,address,trigger_resp_press);
        Screen('Flip', win);
    end
    
    trialTime = toc;

    %% -------- SAVE DATA -------- 
    data.Trial(trial)       = trial; 
    data.CueType(trial)     = cueType;
    data.FlashSide(trial)   = flashSide;
    data.CueValidity(trial) = CueValidity;
    data.probe(trial)       = probe;
    data.ISIframes(trial)   = ISIframes;
    data.dtcolor(trial)     = dtcolor;
    data.Resp(trial)        = resp;
    
    if resp == 1
    data.RespFlash(trial) = "two"; data.ResProbe(trial)  = "top";
    elseif resp == 2
        data.RespFlash(trial) = "one"; data.ResProbe(trial)  = "top";
    elseif resp == 3
        data.RespFlash(trial) = "one"; data.ResProbe(trial)  = "bottom";
    elseif resp == 4
        data.RespFlash(trial) = "two"; data.ResProbe(trial)  = "bottom";
    end

    data.RT(trial)          = rt;
    data.TrialTime(trial)   = trialTime;


    end
       % -------- REST BREAK EVERY 50 TRIALS --------
    if trial > 1 && mod(trial-1,50) == 0

        % ---------------- SAVE CSV ----------------
        csvFile = fullfile(scriptPath, fname);
        writetable(data, csvFile);
        fprintf('CSV saved to:\n%s\n', csvFile);
                
        Screen('FillRect', win, bgcolor);
        DrawFormattedText(win, ...
            'Pause.\n\nQuand vous etes pret, appuyez sur une touche...', ...
            'center','center', flcolor);
        Screen('Flip', win);
        
        % ---------------- WAIT FOR KEY PRESS ----------------
        FlushEvents('keyDown'); % clear prior keys
        keyPressed = 0;
        while ~keyPressed
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown
                if keyCode(KbName('C'))  % C → EyeLink setup
                    % 1. go offline
                    Eyelink('SetOfflineMode'); 
                    WaitSecs(0.5);
                    % 2. run calibration / validation
                    EyelinkDoTrackerSetup(el);
                    % 3. restart recording for next trial
                    Eyelink('StartRecording'); 
                    WaitSecs(0.1);
                elseif keyCode(KbName('N'))  % N → continue
                    keyPressed = 1;
                end
                % wait for key release
                while KbCheck; end
            end
        end
     end
end

%% ================= EYELINK CLEANUP =================
Eyelink('SetOfflineMode');
WaitSecs(0.5);
Eyelink('StopRecording');
Eyelink('CloseFile');
Eyelink('ReceiveFile', fname);

%% -------- SAVE CSV --------
csvFile = fullfile(scriptPath, [fname '.csv']);
writetable(data, csvFile);

%% -------- END MESSAGE --------

Screen('FillRect', win, bgcolor);
DrawFormattedText(win, 'Merci !', 'center', 'center', flcolor);
Screen('Flip', win);

WaitSecs(10);   % show message for seconds
%% ---------------- CLEANUP ----------------
Screen('CloseAll');

%% ---------------- FUNCTIONS ----------------
function sendTrigger(ioObj,address,trig)
    %To EEG
    io64(ioObj,address,trig);
    WaitSecs(0.005);
    io64(ioObj,address,0);
    %To Eyelink
    Eyelink('Message',sprintf('Trigger_%d',trig))

end