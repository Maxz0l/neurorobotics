%% Lab07 - Script 2 - ERD/ERS on spectrogram
% Neurorobotics 2025/2026
%
% Goal:
%   Load the processed PSD data (.mat produced by lab07_01_processing.m),
%   concatenate the runs, build the 4D Activity and Reference matrices, and
%   compute and visualize the ERD/ERS for the two MI classes.
%
% Pipeline:
%   load .mat files
%   -> concatenate PSD and events (window-domain positions)
%   -> extract trials (fixation -> end of continuous feedback)
%   -> build Activity  [windows x frequencies x channels x trials]
%   -> build Reference [windows x frequencies x channels x trials] (fixation)
%   -> ERD = log(Activity ./ Baseline), Baseline = mean over the fixation
%   -> imagesc visualization for C3, Cz, C4, both classes

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

processedDataDir = fullfile(projectRoot, 'data', 'processed');
utilsDir         = fullfile(projectRoot, 'utils');

addpath(utilsDir);

% Processed files (same base names as the GDF runs)
files = {
    'ah7.20170613.161402.offline.mi.mi_bhbf.mat'
    'ah7.20170613.162331.offline.mi.mi_bhbf.mat'
    'ah7.20170613.162934.offline.mi.mi_bhbf.mat'
};

% Event codes
fixEvent   = 786;   % fixation cross  -> start of the trial / reference
cfEvent    = 781;   % continuous feedback -> end of the trial (activity)
classFeet  = 771;   % both feet
classHands = 773;   % both hands

% Meaningful channels for the MI task
selectedChannels = [7 9 11];
channelNames     = {'C3', 'Cz', 'C4'};

% Visualization: rows = classes (top hands, bottom feet, as in the document)
classes    = [classHands classFeet];
classNames = {'Both hands', 'Both feet'};

%% 2. Load and concatenate the processed runs

PSD_all = [];

EVENT_all.TYP = [];
EVENT_all.POS = [];
EVENT_all.DUR = [];

winOffset  = 0;
freqs      = [];
wshift     = [];
samplerate = [];

for iFile = 1:numel(files)

    matPath = fullfile(processedDataDir, files{iFile});

    if ~isfile(matPath)
        error('Processed file not found: %s\nRun lab07_01_processing.m first.', matPath);
    end

    S = load(matPath);   % PSD, freqs, EVENT, samplerate, cfg

    if iFile == 1
        freqs      = S.freqs;
        wshift     = S.cfg.wshift;
        samplerate = S.samplerate;
    end

    % Concatenate PSD along the window dimension
    PSD_all = cat(1, PSD_all, S.PSD);

    % Concatenate events, shifting positions by the cumulative window count
    EVENT_all.TYP = [EVENT_all.TYP; S.EVENT.TYP(:)];
    EVENT_all.POS = [EVENT_all.POS; S.EVENT.POS(:) + winOffset];
    EVENT_all.DUR = [EVENT_all.DUR; S.EVENT.DUR(:)];

    winOffset = winOffset + size(S.PSD, 1);
end

nWindows  = size(PSD_all, 1);
nFreqs    = size(PSD_all, 2);
nChannels = size(PSD_all, 3);

fprintf('--- Concatenated data ---\n');
fprintf('PSD: %d windows x %d frequencies x %d channels\n', nWindows, nFreqs, nChannels);
fprintf('Events: %d\n', numel(EVENT_all.TYP));

%% 3. Extract trial boundaries (window domain)

fixIdxAll = find(EVENT_all.TYP == fixEvent);

trialInfo = struct([]);
nValid = 0;

for iFix = 1:numel(fixIdxAll)

    fixIdx = fixIdxAll(iFix);

    fixPos = EVENT_all.POS(fixIdx);
    fixDur = EVENT_all.DUR(fixIdx);

    % First cue and first continuous feedback after this fixation
    afterFix = (fixIdx + 1):numel(EVENT_all.TYP);

    cueRel = find(ismember(EVENT_all.TYP(afterFix), [classFeet classHands]), 1, 'first');
    if isempty(cueRel)
        continue;
    end
    cueIdx = afterFix(cueRel);

    afterCue = (cueIdx + 1):numel(EVENT_all.TYP);
    cfRel = find(EVENT_all.TYP(afterCue) == cfEvent, 1, 'first');
    if isempty(cfRel)
        continue;
    end
    cfIdx = afterCue(cfRel);

    trialStart = fixPos;
    trialEnd   = EVENT_all.POS(cfIdx) + EVENT_all.DUR(cfIdx) - 1;

    refStart = fixPos;
    refEnd   = fixPos + fixDur - 1;

    if trialStart < 1 || trialEnd > nWindows
        continue;
    end

    nValid = nValid + 1;

    trialInfo(nValid).trialStart = trialStart;
    trialInfo(nValid).trialEnd   = trialEnd;
    trialInfo(nValid).refStart   = refStart;
    trialInfo(nValid).refEnd     = refEnd;
    trialInfo(nValid).cuePos     = EVENT_all.POS(cueIdx);
    trialInfo(nValid).cfPos      = EVENT_all.POS(cfIdx);
    trialInfo(nValid).cue        = EVENT_all.TYP(cueIdx);
end

nTrials = numel(trialInfo);

if nTrials == 0
    error('No valid trials found. Check event codes and the processed data.');
end

Ck = [trialInfo.cue]';

fprintf('\n--- Trials ---\n');
fprintf('Valid trials: %d (feet: %d, hands: %d)\n', ...
    nTrials, sum(Ck == classFeet), sum(Ck == classHands));

%% 4. Build the 4D Activity and Reference matrices

trialLengths = arrayfun(@(x) x.trialEnd - x.trialStart + 1, trialInfo);
refLengths   = arrayfun(@(x) x.refEnd   - x.refStart   + 1, trialInfo);

minTrialLen = min(trialLengths);
minRefLen   = min(refLengths);

Activity  = zeros(minTrialLen, nFreqs, nChannels, nTrials);
Reference = zeros(minRefLen,   nFreqs, nChannels, nTrials);

for iTrial = 1:nTrials

    tStart = trialInfo(iTrial).trialStart;
    rStart = trialInfo(iTrial).refStart;

    tIdx = tStart:(tStart + minTrialLen - 1);
    rIdx = rStart:(rStart + minRefLen - 1);

    Activity(:, :, :, iTrial)  = PSD_all(tIdx, :, :);
    Reference(:, :, :, iTrial) = PSD_all(rIdx, :, :);
end

fprintf('\n--- 4D matrices ---\n');
fprintf('Activity:  %s\n', mat2str(size(Activity)));
fprintf('Reference: %s\n', mat2str(size(Reference)));

%% 5. Compute ERD/ERS (log ratio, trial by trial)

% Baseline = average over the fixation windows, replicated to the trial length
Baseline = repmat(mean(Reference, 1), [size(Activity, 1) 1 1 1]);

ERD = log(Activity ./ Baseline);
% Alternative (percentage form, see the slides):
% ERD = 100 * (Activity - Baseline) ./ Baseline;

%% 6. Class-average ERD/ERS and common color scale

timeVec = (0:minTrialLen - 1) * wshift;   % s, one window every wshift seconds

avgERDByClass = cell(numel(classes), 1);
for r = 1:numel(classes)
    avgERDByClass{r} = mean(ERD(:, :, :, Ck == classes(r)), 4);   % [win x freq x chan]
end

% Common color limits over the displayed channels and classes
dispVals = [];
for r = 1:numel(classes)
    for c = 1:numel(selectedChannels)
        block = avgERDByClass{r}(:, :, selectedChannels(c));
        dispVals = [dispVals; block(:)]; %#ok<AGROW>
    end
end
cLim = [min(dispVals) max(dispVals)];

% Cue and feedback onsets relative to the fixation (median across trials)
cueRel = arrayfun(@(x) x.cuePos - x.trialStart, trialInfo);
cfRel  = arrayfun(@(x) x.cfPos  - x.trialStart, trialInfo);
cueSec = median(cueRel) * wshift;
cfSec  = median(cfRel)  * wshift;

%% 7. Visualization with imagesc

figure('Name', 'Lab07 - ERD/ERS on spectrogram', 'Color', 'w');

for r = 1:numel(classes)
    for c = 1:numel(selectedChannels)

        ch  = selectedChannels(c);
        img = squeeze(avgERDByClass{r}(:, :, ch))';   % [freq x win]

        subplot(numel(classes), numel(selectedChannels), ...
            (r - 1) * numel(selectedChannels) + c);

        imagesc(timeVec, freqs, img, cLim);
        axis xy;
        colormap(hot);

        hold on;
        xline(cueSec, 'k-', 'LineWidth', 1);
        xline(cfSec,  'k-', 'LineWidth', 1);
        hold off;

        xlabel('Time [s]');
        ylabel('Frequency [Hz]');
        title(sprintf('Channel %s | %s', channelNames{c}, classNames{r}));
        colorbar;
    end
end

sgtitle('ERD/ERS on spectrogram - log(Activity / Reference)');

%% 8. Final summary

fprintf('\n--- Lab07 script 2 completed ---\n');
fprintf('Trials: %d (feet: %d, hands: %d)\n', ...
    nTrials, sum(Ck == classFeet), sum(Ck == classHands));
fprintf('Trial length: %.2f s (%d windows)\n', timeVec(end), minTrialLen);
fprintf('Color scale: [%.2f, %.2f]\n', cLim(1), cLim(2));
