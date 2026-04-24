%% Visual two-flash fusion experiment with spatial probes

clear; clc;
Screen('Preference', 'SkipSyncTests', 1);

%% ---------------- INITIATION ----------------
fname = 'subIntro.csv';

% Refreash rate
expectedRefreshRate = 144; %Hz

% Cue
cueFrames = round(1 * expectedRefreshRate); % 1000 ms

% Temporal parameter
flashFrames = 1;
ISIframes   = 1;
ITIframes   = round(1.0 * expectedRefreshRate); 

% Spacial parameters
eccentricityDeg = 10;
flashSizeDeg    = 2;

lineLengthPix = 9;
lineWidthPix  = 4;
lineSpacingPix = 5;

cueSize = 40;

% Contrast
bgcolor = 0;
flcolor = 255;
dtcolor = 0;


% Response
 respFrames = round(10.0 * expectedRefreshRate); % 10 second    
 

 devices = PsychHID('Devices');

 keyboardIndices = [];
 for i = 1:length(devices)
        if devices(i).usageValue == 6   % 6 = keyboard
            keyboardIndices(end+1) = i;
            fprintf('Keyboard %d: %s\n', i, devices(i).product);
        end
 end

  KbName('UnifyKeyNames');
    
  keys = {'1!','2@','3#','4$'};


  keyCodes = KbName(keys);

  axisLength = 250; % Size of the quadrant
  quadSize   = 200;


%% ---------------- SCREEN SETUP ----------------
screenNumber = 0;
[win, winRect] = Screen('OpenWindow', screenNumber, bgcolor);
Screen('TextSize', win, cueSize);

ifi = Screen('GetFlipInterval', win);
[xCenter, yCenter] = RectCenter(winRect);

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

%% ---------------- CUE PARAMETERS ----------------
arrowSize = 40;
arrowWidth = 6;
lineLengthCue = 80;


%% ---------------- Load trial list ----------------
[scriptPath,~,~] = fileparts(mfilename('fullpath'));
load(fullfile(scriptPath, 'trialListIntro.mat'));

nTrials = height(trialList);

data = table('Size',[nTrials 12], ...
    'VariableTypes',{'double','string','string','string','string','string','string',...
                    'double','string','string','double','double'}, ...
    'VariableNames',{'Trial','CueType','FlashSide','CueValidity','probe','ISIframes','dtcolor', ...
                     'Resp','RespFlash','ResProbe', 'RT','TrialTime'});

vbl = Screen('Flip', win);

%% ================== MAIN LOOP ==================

% -------- First REST BREAK --------
    Screen('FillRect', win, bgcolor);
    DrawFormattedText(win, ...
            'Quand vous etes pret, appuyez sur une touche...', ...
            'center','center', flcolor);
    Screen('Flip', win);
        
    KbStrokeWait;   % wait for key press
        
    vbl = Screen('Flip', win); % reset flip timing

% -------- LOOP STARTS --------
for trial = 1:nTrials

    cueType   = trialList.cueType(trial);
    flashSide = trialList.flashSide(trial);
    ISIframes = trialList.ISIframes(trial);
    dtcolor   = trialList.dtcolor(trial);
    probe     = trialList.probe(trial);
    CueValidity= trialList.CueValidity(trial);
    
    resp = NaN;
    rt   = NaN;

    while isnan(resp)

    tic          % Start timer

    % -------- FIXATION --------
    fixFrames = randi([fixMinFrames fixMaxFrames]);

    for f = 1:fixFrames
        Screen('FillRect', win, bgcolor);
        Screen('DrawLines', win, fixCoords, 2, flcolor, [xCenter yCenter]);
        vbl = Screen('Flip', win, vbl + ifi);
    end

   %% -------- CUE --------1
    
    Screen('FillRect', win, bgcolor);
    
    if cueType == "left"
        cueSign = 'o';
    
    elseif cueType == "right"
        cueSign = '*';
    
    elseif cueType == "neutral" 
        cueSign = 'x';
    end
    
    % Present cue for cueFrames frames
    vbl = Screen('Flip', win);  % initial sync
    
    for f = 1:cueFrames
        
        Screen('FillRect', win, bgcolor); % clear background each frame
        DrawFormattedText(win, cueSign, 'center', 'center', flcolor);
        
        vbl = Screen('Flip', win, vbl + 0.5 * ifi);
    end
    %% -------- SETUP STIMULI --------
    % -------- FLASH SIDE --------
    if flashSide == "left"
        xPos = xCenter - eccentricityPix;
    else
        xPos = xCenter + eccentricityPix;
    end

    flashRect = CenterRectOnPointd([0 0 flashSizePix flashSizePix], xPos, yCenter);

    % -------- probe POSITIONS --------
    xOffsets = [-2 -1 0 1 2] * lineSpacingPix;

    % Flash 1
    if probe == "top"
        lineCenterY1 = flashRect(2) + lineWidthPix;
    else
        lineCenterY1 = flashRect(4) - lineWidthPix;
    end

    lineCoords1 = [];
    for i = 1:length(xOffsets)
        xLine = xPos + xOffsets(i);
        thisLine = [
            xLine, xLine;
            lineCenterY1 - lineLengthPix/2, ...
            lineCenterY1 + lineLengthPix/2
        ];
        lineCoords1 = [lineCoords1 thisLine];
    end

    % Flash 2
    if probe == "top"
        lineCenterY2 = flashRect(2) + lineWidthPix;
    else
        lineCenterY2 = flashRect(4) - lineWidthPix;
    end

    lineCoords2 = [];
    for i = 1:length(xOffsets)
        xLine = xPos + xOffsets(i);
        thisLine = [
            xLine, xLine;
            lineCenterY2 - lineLengthPix/2, ...
            lineCenterY2 + lineLengthPix/2
        ];
        lineCoords2 = [lineCoords2 thisLine];
    end

    %% -------- STIMULI --------
    % -------- FIRST FLASH --------
    Screen('FillRect', win, flcolor, flashRect);
    Screen('DrawLines', win, lineCoords1, lineWidthPix, dtcolor);
    vbl = Screen('Flip', win);
    vbl = Screen('Flip', win, vbl + flashFrames * ifi);

    % -------- ISI --------
    Screen('FillRect', win, bgcolor);
    vbl = Screen('Flip', win, vbl + ISIframes * ifi);

    % -------- SECOND FLASH --------
    Screen('FillRect', win, flcolor, flashRect);
    Screen('DrawLines', win, lineCoords2, lineWidthPix, dtcolor);
    vbl = Screen('Flip', win);
    vbl = Screen('Flip', win, vbl + flashFrames * ifi);

    %% -------- RESPONSE PLACEHOLDER --------
    
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
        
        KbStrokeWait;   % wait for key press
        
        vbl = Screen('Flip', win); % reset flip timing
    end
end

%% -------- END MESSAGE --------

Screen('FillRect', win, bgcolor);
DrawFormattedText(win, 'Merci !', 'center', 'center', flcolor);
Screen('Flip', win);

WaitSecs(10);   % show message for seconds

% ----------- SAVE CSV ----------------
csvFile = fullfile(scriptPath, fname);
writetable(data, csvFile);
fprintf('CSV saved to:\n%s\n', csvFile);


%% ---------------- CLEANUP ----------------
Screen('CloseAll');

