%% Lab08 - Feature selection and classification
% Neurorobotics 2025/2026
%
% Goal:
%   Load the PSD data processed in Lab07 (data/processed/*.mat), compute the
%   Fisher score of every channel-frequency feature, select the most
%   discriminative ones, train an LDA/QDA decoder, and evaluate it.
%
% Pipeline:
%   load .mat (reuse Lab07 processing) -> concatenate
%   -> build per-window label vectors (Ck class, CFbk feedback, Rk run)
%   -> features = log(PSD) reshaped to [windows x features]
%   -> Fisher score (per run for the maps, overall for selection)
%   -> select the top features
%   -> fitcdiscr() to train, predict() to evaluate
%   -> feature maps, 2D classifier space, accuracy bar plot
%
% Note: the processing step (script 1 of the assignment) is identical to
% Lab07 and is NOT repeated here. We reuse the .mat produced by
% lab07_01_processing.m.

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

processedDataDir = fullfile(projectRoot, 'data', 'processed');
utilsDir         = fullfile(projectRoot, 'utils');

addpath(utilsDir);

files = {
    'ah7.20170613.161402.offline.mi.mi_bhbf.mat'
    'ah7.20170613.162331.offline.mi.mi_bhbf.mat'
    'ah7.20170613.162934.offline.mi.mi_bhbf.mat'
};

% Event codes
fixEvent   = 786;   % fixation cross
cfEvent    = 781;   % continuous feedback (training period)
classFeet  = 771;   % both feet
classHands = 773;   % both hands

classes     = [classFeet classHands];
classLabels = {'Both feet', 'Both hands'};

% 16-channel layout (from the expected feature maps)
channelNames = {'Fz','FC3','FC1','FCz','FC2','FC4','C3','C1','Cz','C2','C4', ...
                'CP3','CP1','CPz','CP2','CP4'};

% Number of features to select and discriminant type
nSelected   = 2;            % 2 reproduces the 2D classifier-space figure
discrimType = 'quadratic';  % linear | diaglinear | quadratic | diagquadratic

%% 2. Load and concatenate the processed runs

PSD_all = [];

EVENT_all.TYP = [];
EVENT_all.POS = [];
EVENT_all.DUR = [];

runSizes = zeros(numel(files), 1);   % number of windows per run
winOffset = 0;
freqs = [];

for iFile = 1:numel(files)

    matPath = fullfile(processedDataDir, files{iFile});
    if ~isfile(matPath)
        error('Processed file not found: %s\nRun lab07_01_processing.m first.', matPath);
    end

    S = load(matPath);   % PSD, freqs, EVENT, samplerate, cfg

    if iFile == 1
        freqs = S.freqs(:)';
    end

    PSD_all = cat(1, PSD_all, S.PSD);

    EVENT_all.TYP = [EVENT_all.TYP; S.EVENT.TYP(:)];
    EVENT_all.POS = [EVENT_all.POS; S.EVENT.POS(:) + winOffset];
    EVENT_all.DUR = [EVENT_all.DUR; S.EVENT.DUR(:)];

    runSizes(iFile) = size(S.PSD, 1);
    winOffset = winOffset + size(S.PSD, 1);
end

[nWin, nFreq, nChan] = size(PSD_all);

fprintf('--- Concatenated data ---\n');
fprintf('PSD: %d windows x %d frequencies x %d channels\n', nWin, nFreq, nChan);

%% 3. Build per-window label vectors

Ck   = zeros(nWin, 1);   % class active during the trial (771/773)
CFbk = zeros(nWin, 1);   % 781 during the continuous feedback period
Rk   = zeros(nWin, 1);   % run index per window

% Run index per window (runs are contiguous blocks of windows)
runOffset = 0;
for iFile = 1:numel(files)
    Rk(runOffset + (1:runSizes(iFile))) = iFile;
    runOffset = runOffset + runSizes(iFile);
end

% Fill Ck and CFbk by walking through the trials (fixation -> cue -> feedback)
fixIdxAll = find(EVENT_all.TYP == fixEvent);

for iFix = 1:numel(fixIdxAll)

    fixIdx = fixIdxAll(iFix);
    afterFix = (fixIdx + 1):numel(EVENT_all.TYP);

    cueRel = find(ismember(EVENT_all.TYP(afterFix), classes), 1, 'first');
    if isempty(cueRel); continue; end
    cueIdx = afterFix(cueRel);

    afterCue = (cueIdx + 1):numel(EVENT_all.TYP);
    cfRel = find(EVENT_all.TYP(afterCue) == cfEvent, 1, 'first');
    if isempty(cfRel); continue; end
    cfIdx = afterCue(cfRel);

    cuePos  = EVENT_all.POS(cueIdx);
    cfStart = EVENT_all.POS(cfIdx);
    cfEnd   = cfStart + EVENT_all.DUR(cfIdx) - 1;

    if cfEnd > nWin; continue; end

    Ck(cuePos:cfEnd)   = EVENT_all.TYP(cueIdx);   % class from cue to end of CF
    CFbk(cfStart:cfEnd) = cfEvent;                % continuous feedback windows
end

fprintf('Continuous-feedback windows: %d (feet: %d, hands: %d)\n', ...
    sum(CFbk == cfEvent), ...
    sum(CFbk == cfEvent & Ck == classFeet), ...
    sum(CFbk == cfEvent & Ck == classHands));

%% 4. Build the feature matrix (log PSD), [windows x features]

% Column-major reshape: feature k -> freq = mod(k-1,nFreq)+1, channel = floor((k-1)/nFreq)+1
F = log(reshape(PSD_all, nWin, nFreq * nChan));

nFeatures   = nFreq * nChan;
featFreqIdx = mod((1:nFeatures) - 1, nFreq) + 1;
featChanIdx = floor(((1:nFeatures) - 1) / nFreq) + 1;

%% 5. Fisher score (per run for the maps, overall for selection)

% Fisher score for every feature (see utils/compute_fisher_score.m)
fisherRun = zeros(numel(files), nFeatures);

for r = 1:numel(files)
    mask = (Rk == r) & (CFbk == cfEvent);
    fisherRun(r, :) = compute_fisher_score(F(mask, :), Ck(mask));
end

maskAll       = (CFbk == cfEvent);
fisherOverall = compute_fisher_score(F(maskAll, :), Ck(maskAll));

%% 6. Feature selection (top nSelected by overall Fisher score)

[~, ranking] = sort(fisherOverall, 'descend');
selIdx = ranking(1:nSelected);

selNames = arrayfun(@(k) sprintf('%s@%dHz', channelNames{featChanIdx(k)}, freqs(featFreqIdx(k))), ...
    selIdx, 'UniformOutput', false);

fprintf('\n--- Selected features ---\n');
for i = 1:nSelected
    fprintf('  %d) %s (Fisher = %.3f)\n', i, selNames{i}, fisherOverall(selIdx(i)));
end

%% 7. Figure 1 - Fisher score feature maps (one per run)

fisherCLim = [0 max(fisherRun(:))];   % common color scale across the runs

figure('Name', 'Lab08 - Fisher score feature maps', 'Color', 'w');

for r = 1:numel(files)
    ax = subplot(1, numel(files), r);

    % Row 1 = Fz at the top (no 'axis xy'), matching the expected maps
    fmap = reshape(fisherRun(r, :), nFreq, nChan)';   % [channels x freqs]
    imagesc(freqs, 1:nChan, fmap, fisherCLim);
    colormap(parula);

    hold on;
    for i = 1:nSelected
        plot(freqs(featFreqIdx(selIdx(i))), featChanIdx(selIdx(i)), ...
            'o', 'MarkerSize', 10, 'MarkerEdgeColor', 'r', 'LineWidth', 1.8);
    end
    hold off;

    % Force a light theme so the figure is readable in MATLAB dark mode
    set(ax, 'YTick', 1:nChan, 'YTickLabel', channelNames, ...
        'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'FontSize', 9);
    xlabel('Frequency [Hz]', 'Color', 'k');
    ylabel('Channel', 'Color', 'k');
    title(sprintf('Calibration run %d', r), 'Color', 'k');
end

sgtitle('Fisher score (red circles = selected features)', 'Color', 'k');

%% 8. Train the decoder (continuous feedback windows only)

trainMask = (CFbk == cfEvent);

Fsel  = F(:, selIdx);
Ftrain = Fsel(trainMask, :);
ytrain = Ck(trainMask);

Model = fitcdiscr(Ftrain, ytrain, 'DiscrimType', discrimType);

%% 9. Evaluate (single-sample accuracy on the training set)

Gk = predict(Model, Ftrain);

accOverall = 100 * mean(Gk == ytrain);
accFeet    = 100 * mean(Gk(ytrain == classFeet)  == classFeet);
accHands   = 100 * mean(Gk(ytrain == classHands) == classHands);

fprintf('\n--- Single-sample accuracy (trainset) ---\n');
fprintf('Overall:    %.2f %%\n', accOverall);
fprintf('Both hands: %.2f %%\n', accHands);
fprintf('Both feet:  %.2f %%\n', accFeet);

%% 10. Figure 2 - Classifier space of the two selected features

if nSelected == 2

    figure('Name', 'Lab08 - Classifier space', 'Color', 'w');
    ax = gca;
    hold on;

    feetRows  = ytrain == classFeet;
    handsRows = ytrain == classHands;

    % Semi-transparent filled markers so the dense clusters stay readable
    hFeet  = scatter(Ftrain(feetRows, 1),  Ftrain(feetRows, 2),  14, ...
        'Marker', 'o', 'MarkerEdgeColor', 'none', ...
        'MarkerFaceColor', [0.15 0.15 0.15], 'MarkerFaceAlpha', 0.25);
    hHands = scatter(Ftrain(handsRows, 1), Ftrain(handsRows, 2), 14, ...
        'Marker', '^', 'MarkerEdgeColor', 'none', ...
        'MarkerFaceColor', [0.10 0.45 0.90], 'MarkerFaceAlpha', 0.25);

    % Decision boundary via a prediction grid
    x1 = linspace(min(Ftrain(:,1)), max(Ftrain(:,1)), 300);
    x2 = linspace(min(Ftrain(:,2)), max(Ftrain(:,2)), 300);
    [X1, X2] = meshgrid(x1, x2);
    Ggrid = reshape(predict(Model, [X1(:) X2(:)]), size(X1));

    [~, hB] = contour(X1, X2, double(Ggrid == classHands), [0.5 0.5], 'r', 'LineWidth', 2);

    set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
    xlabel(selNames{1}, 'Color', 'k');
    ylabel(selNames{2}, 'Color', 'k');
    title('Classifier space of two features', 'Color', 'k');
    legend([hFeet hHands hB], {'both feet', 'both hands', 'Boundary'}, ...
        'Location', 'best', 'TextColor', 'k');
    grid on;
    hold off;
end

%% 11. Figure 3 - Single-sample accuracy bar plot

figure('Name', 'Lab08 - Single sample accuracy', 'Color', 'w');

accValues = [accOverall, accHands, accFeet];
bar(accValues, 'FaceColor', [0.10 0.45 0.90]);

% Value label on top of each bar
text(1:numel(accValues), accValues + 2, compose('%.1f%%', accValues), ...
    'HorizontalAlignment', 'center', 'Color', 'k', 'FontWeight', 'bold');

set(gca, 'XTickLabel', {'overall', 'both hands', 'both feet'}, ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
ylabel('accuracy [%]', 'Color', 'k');
ylim([0 100]);
title('Single sample accuracy on trainset', 'Color', 'k');
grid on;

%% 12. Final summary

fprintf('\n--- Lab08 completed ---\n');
fprintf('Features: %d (%d channels x %d frequencies)\n', nFeatures, nChan, nFreq);
fprintf('Selected: %s\n', strjoin(selNames, ', '));
fprintf('Model: fitcdiscr (%s)\n', discrimType);
fprintf('Overall accuracy: %.2f %%\n', accOverall);
