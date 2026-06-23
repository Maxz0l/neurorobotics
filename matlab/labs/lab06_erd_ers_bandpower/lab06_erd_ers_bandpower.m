%% Lab06 - ERD/ERS on bandpower
% Neurorobotics 2025/2026
%
% Goal:
% Compute ERD/ERS on non-logarithmic mu and beta bandpower.
%
% Inputs:
% - Offline GDF files
% - laplacian16.mat
% - chanlocs16.mat
%
% Outputs:
% - Temporal ERD/ERS plots
% - Spatial ERD/ERS topoplots

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

rawDataDir  = fullfile(projectRoot, 'data', 'raw');
externalDir = fullfile(projectRoot, 'data', 'external');
utilsDir    = fullfile(projectRoot, 'utils');

addpath(utilsDir);

files = {
    'ah7.20170613.161402.offline.mi.mi_bhbf.gdf'
    'ah7.20170613.162331.offline.mi.mi_bhbf.gdf'
    'ah7.20170613.162934.offline.mi.mi_bhbf.gdf'
};

lapFile     = fullfile(externalDir, 'laplacian16.mat');
chanlocFile = fullfile(externalDir, 'chanlocs16.mat');

muBand   = [8 12];
betaBand = [18 30];

filterOrder = 4;
movingWindowSec = 1;

classFeet  = 771;
classHands = 773;

fixEvent = 786;
cfEvent  = 781;

selectedChannel = 7;   % C3 in the 16-channel layout (7 = C3, 9 = Cz, 11 = C4)

feetColor  = [0.20 0.60 1.00];
handsColor = [1.00 0.45 0.20];

darkFigColor = [0.10 0.10 0.10];
darkAxColor  = [0.15 0.15 0.15];

%% 2. Load and concatenate GDF files

[S_eeg_all, ~, EVENT_all, ~, ~, sampleRate] = concat_gdf_runs(files, rawDataDir);

%% 3. Apply Laplacian spatial filter

S_lap = apply_laplacian_filter(S_eeg_all, lapFile);

%% 4. Compute mu and beta bandpower without log

[powerMu, ~, ~] = compute_bandpower( ...
    S_lap, sampleRate, muBand, ...
    'ApplyLog', false, ...
    'FilterOrder', filterOrder, ...
    'MovingWindowSec', movingWindowSec);

[powerBeta, ~, ~] = compute_bandpower( ...
    S_lap, sampleRate, betaBand, ...
    'ApplyLog', false, ...
    'FilterOrder', filterOrder, ...
    'MovingWindowSec', movingWindowSec);

%% 5. Extract trial information from events

fixEventIdxAll = find(EVENT_all.TYP == fixEvent);

trialInfo = struct([]);
validTrialCount = 0;

for iFix = 1:numel(fixEventIdxAll)

    fixEventIdx = fixEventIdxAll(iFix);

    fixPos = EVENT_all.POS(fixEventIdx);
    fixDur = EVENT_all.DUR(fixEventIdx);

    nextEventsIdx = fixEventIdx+1:numel(EVENT_all.TYP);

    cueRelIdx = find(ismember(EVENT_all.TYP(nextEventsIdx), [classFeet classHands]), 1, 'first');

    if isempty(cueRelIdx)
        continue;
    end

    cueEventIdx = nextEventsIdx(cueRelIdx);

    afterCueEventsIdx = cueEventIdx+1:numel(EVENT_all.TYP);
    cfRelIdx = find(EVENT_all.TYP(afterCueEventsIdx) == cfEvent, 1, 'first');

    if isempty(cfRelIdx)
        continue;
    end

    cfEventIdx = afterCueEventsIdx(cfRelIdx);

    cueType = EVENT_all.TYP(cueEventIdx);
    cuePos  = EVENT_all.POS(cueEventIdx);

    cfPos = EVENT_all.POS(cfEventIdx);
    cfDur = EVENT_all.DUR(cfEventIdx);

    trialStart = fixPos;
    trialEnd   = cfPos + cfDur - 1;

    if trialEnd > size(powerMu, 1)
        continue;
    end

    validTrialCount = validTrialCount + 1;

    trialInfo(validTrialCount).trialStart = trialStart;
    trialInfo(validTrialCount).trialEnd   = trialEnd;

    trialInfo(validTrialCount).fixStart = fixPos;
    trialInfo(validTrialCount).fixEnd   = fixPos + fixDur - 1;

    trialInfo(validTrialCount).cueStart = cuePos;

    trialInfo(validTrialCount).cfStart = cfPos;
    trialInfo(validTrialCount).cfEnd   = cfPos + cfDur - 1;

    trialInfo(validTrialCount).cue = cueType;
end

nTrials = numel(trialInfo);

if nTrials == 0
    error('No valid trials found. Check event codes and EVENT structure.');
end

Ck = [trialInfo.cue]';

%% 6. Build trial and fixation matrices

trialLengths = arrayfun(@(x) x.trialEnd - x.trialStart + 1, trialInfo);
fixLengths   = arrayfun(@(x) x.fixEnd   - x.fixStart   + 1, trialInfo);

minTrialLength = min(trialLengths);
minFixLength   = min(fixLengths);

nChannels = size(powerMu, 2);

TrialMu   = zeros(minTrialLength, nChannels, nTrials);
TrialBeta = zeros(minTrialLength, nChannels, nTrials);

FixMu   = zeros(minFixLength, nChannels, nTrials);
FixBeta = zeros(minFixLength, nChannels, nTrials);

for iTrial = 1:nTrials

    trialStart = trialInfo(iTrial).trialStart;
    fixStart   = trialInfo(iTrial).fixStart;

    trialIdx = trialStart:(trialStart + minTrialLength - 1);
    fixIdx   = fixStart:(fixStart + minFixLength - 1);

    TrialMu(:, :, iTrial)   = powerMu(trialIdx, :);
    TrialBeta(:, :, iTrial) = powerBeta(trialIdx, :);

    FixMu(:, :, iTrial)   = powerMu(fixIdx, :);
    FixBeta(:, :, iTrial) = powerBeta(fixIdx, :);
end

%% 7. Compute ERD/ERS

RefMu   = repmat(mean(FixMu, 1),   [size(TrialMu, 1),   1, 1]);
RefBeta = repmat(mean(FixBeta, 1), [size(TrialBeta, 1), 1, 1]);

ERD_Mu   = 100 * (TrialMu   - RefMu)   ./ (RefMu   + eps);
ERD_Beta = 100 * (TrialBeta - RefBeta) ./ (RefBeta + eps);

%% 8. Prepare class averages

timeVector = (0:minTrialLength-1) / sampleRate;

feetIdx  = Ck == classFeet;
handsIdx = Ck == classHands;

muFeetMean    = mean(ERD_Mu(:, selectedChannel, feetIdx), 3);
muHandsMean   = mean(ERD_Mu(:, selectedChannel, handsIdx), 3);
betaFeetMean  = mean(ERD_Beta(:, selectedChannel, feetIdx), 3);
betaHandsMean = mean(ERD_Beta(:, selectedChannel, handsIdx), 3);

muFeetSE    = std(ERD_Mu(:, selectedChannel, feetIdx), 0, 3) / sqrt(sum(feetIdx));
muHandsSE   = std(ERD_Mu(:, selectedChannel, handsIdx), 0, 3) / sqrt(sum(handsIdx));
betaFeetSE  = std(ERD_Beta(:, selectedChannel, feetIdx), 0, 3) / sqrt(sum(feetIdx));
betaHandsSE = std(ERD_Beta(:, selectedChannel, handsIdx), 0, 3) / sqrt(sum(handsIdx));

cueStartsRel = arrayfun(@(x) x.cueStart - x.trialStart + 1, trialInfo);
cfStartsRel  = arrayfun(@(x) x.cfStart  - x.trialStart + 1, trialInfo);

cueStartSec = median(cueStartsRel) / sampleRate;
cfStartSec  = median(cfStartsRel)  / sampleRate;

%% 9. Temporal visualization

bands      = {'\mu', '\beta'};
feetMeans  = {muFeetMean,  betaFeetMean};
handsMeans = {muHandsMean, betaHandsMean};
feetSEs    = {muFeetSE,    betaFeetSE};
handsSEs   = {muHandsSE,   betaHandsSE};

figure('Name', 'Lab06 - Temporal ERD/ERS', 'Color', darkFigColor);

for b = 1:numel(bands)

    feetMean  = feetMeans{b};   feetSE  = feetSEs{b};
    handsMean = handsMeans{b};  handsSE = handsSEs{b};

    subplot(2, 1, b);
    hold on;

    hFeet = plot(timeVector, feetMean, 'Color', feetColor, 'LineWidth', 1.6);
    plot(timeVector, feetMean + feetSE, '--', 'Color', feetColor, 'LineWidth', 0.8);
    plot(timeVector, feetMean - feetSE, '--', 'Color', feetColor, 'LineWidth', 0.8);

    hHands = plot(timeVector, handsMean, 'Color', handsColor, 'LineWidth', 1.6);
    plot(timeVector, handsMean + handsSE, '--', 'Color', handsColor, 'LineWidth', 0.8);
    plot(timeVector, handsMean - handsSE, '--', 'Color', handsColor, 'LineWidth', 0.8);

    yline(0, ':', 'Color', [0.8 0.8 0.8], 'LineWidth', 1);

    xline(cueStartSec, '--', 'Cue', ...
        'Color', [0.9 0.9 0.9], 'LineWidth', 1, 'LabelVerticalAlignment', 'top');
    xline(cfStartSec, '--', 'Feedback', ...
        'Color', [0.9 0.9 0.9], 'LineWidth', 1, 'LabelVerticalAlignment', 'top');

    grid on;
    xlabel('Time from fixation onset [s]');
    ylabel('ERD/ERS [%]');
    axis tight;   % auto Y scaling (no fixed limit)
    title(sprintf('%s band ERD/ERS - Channel %d', bands{b}, selectedChannel));
    legend([hFeet hHands], {'Feet', 'Hands'}, 'Location', 'best');

    ax = gca;
    ax.Color = darkAxColor;
    ax.XColor = 'w';
    ax.YColor = 'w';
    ax.GridColor = [0.6 0.6 0.6];
    ax.Title.Color = 'w';
    ax.XLabel.Color = 'w';
    ax.YLabel.Color = 'w';

    lgd = legend;
    lgd.TextColor = 'w';
    lgd.Color = darkAxColor;
    lgd.EdgeColor = [0.6 0.6 0.6];
end

%% 10. Spatial visualization

chanlocData = load(chanlocFile);

if isfield(chanlocData, 'chanlocs16')
    chanlocs = chanlocData.chanlocs16;
elseif isfield(chanlocData, 'chanlocs')
    chanlocs = chanlocData.chanlocs;
else
    error('No channel location variable found in chanlocs16.mat.');
end

fixPeriod = 1:minFixLength;

cfStartsRel = arrayfun(@(x) x.cfStart - x.trialStart + 1, trialInfo);
cfEndsRel   = arrayfun(@(x) x.cfEnd   - x.trialStart + 1, trialInfo);

cfStartRel = round(median(cfStartsRel));
cfEndRel   = min(round(median(cfEndsRel)), minTrialLength);

cfPeriod = cfStartRel:cfEndRel;

ERD_Mu_Ref_Feet  = squeeze(mean(mean(ERD_Mu(fixPeriod, :, feetIdx), 1), 3));
ERD_Mu_Act_Feet  = squeeze(mean(mean(ERD_Mu(cfPeriod,  :, feetIdx), 1), 3));
ERD_Mu_Ref_Hands = squeeze(mean(mean(ERD_Mu(fixPeriod, :, handsIdx), 1), 3));
ERD_Mu_Act_Hands = squeeze(mean(mean(ERD_Mu(cfPeriod,  :, handsIdx), 1), 3));

% Only the label text is styled, in a dark color
labelColor = [0.15 0.15 0.15];

figure('Name', 'Lab06 - Spatial ERD/ERS Mu');

subplot(2, 2, 1);
topoplot(ERD_Mu_Ref_Feet, chanlocs);
title('Feet - Reference', 'Color', labelColor);
colorbar;

subplot(2, 2, 2);
topoplot(ERD_Mu_Act_Feet, chanlocs);
title('Feet - Activity', 'Color', labelColor);
colorbar;

subplot(2, 2, 3);
topoplot(ERD_Mu_Ref_Hands, chanlocs);
title('Hands - Reference', 'Color', labelColor);
colorbar;

subplot(2, 2, 4);
topoplot(ERD_Mu_Act_Hands, chanlocs);
title('Hands - Activity', 'Color', labelColor);
colorbar;

sgtitle('\mu band ERD/ERS topography', 'Color', labelColor);

%% 11. Final summary

fprintf('\n--- Lab06 completed ---\n');
fprintf('Valid trials: %d\n', nTrials);
fprintf('Feet trials: %d\n', sum(feetIdx));
fprintf('Hands trials: %d\n', sum(handsIdx));