%% Lab09 - Script 3 - Test the decoder and apply the control framework
% Neurorobotics 2025/2026
%
% Goal:
%   Apply the decoder trained in script 2 to the ONLINE evaluation runs:
%     - single-sample accuracy on the test set
%     - exponential evidence accumulation (control framework)
%     - trial-based accuracy, without and with rejection
%
% Pipeline:
%   load decoder + online .mat -> features -> predict (posterior pp)
%   -> single-sample accuracy
%   -> exponential accumulation D(t) (reset at each trial)
%   -> per-trial decision by threshold crossing -> trial accuracy

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

processedDataDir = fullfile(projectRoot, 'data', 'processed');
utilsDir         = fullfile(projectRoot, 'utils');

addpath(utilsDir);

% Evaluation (online) runs
evaluationFiles = {
    'ah7.20170613.170929.online.mi.mi_bhbf.ema.mat'
    'ah7.20170613.171649.online.mi.mi_bhbf.dynamic.mat'
    'ah7.20170613.172356.online.mi.mi_bhbf.dynamic.mat'
    'ah7.20170613.173100.online.mi.mi_bhbf.ema.mat'
};

decoderFile = fullfile(processedDataDir, 'decoder_bhbf.mat');

% Event codes
cfEvent    = 781;
classFeet  = 771;
classHands = 773;
classes    = [classFeet classHands];

% Control framework parameters
% Convention from the slides: D(t) = alpha*D(t-1) + (1-alpha)*pp(t)
% (alpha is the "memory": closer to 1 = stronger smoothing)
alpha     = 0.96;
thLow     = 0.2;    % decision toward class 2 (hands) when D(:,1) <= thLow
thHigh    = 0.8;    % decision toward class 1 (feet)  when D(:,1) >= thHigh

exampleTrial = 55;  % trial index used for the evidence-accumulation figure

%% 2. Load the decoder

if ~isfile(decoderFile)
    error('Decoder not found: %s\nRun lab09_02_training.m first.', decoderFile);
end
load(decoderFile, 'decoder');

%% 3. Load and concatenate the online runs

PSD_all = [];
EVENT_all.TYP = [];
EVENT_all.POS = [];
EVENT_all.DUR = [];
winOffset = 0;

for iFile = 1:numel(evaluationFiles)

    matPath = fullfile(processedDataDir, evaluationFiles{iFile});
    if ~isfile(matPath)
        error('Processed file not found: %s\nRun lab09_01_processing.m first.', matPath);
    end

    S = load(matPath);
    PSD_all = cat(1, PSD_all, S.PSD);
    EVENT_all.TYP = [EVENT_all.TYP; S.EVENT.TYP(:)];
    EVENT_all.POS = [EVENT_all.POS; S.EVENT.POS(:) + winOffset];
    EVENT_all.DUR = [EVENT_all.DUR; S.EVENT.DUR(:)];
    winOffset = winOffset + size(S.PSD, 1);
end

[nWin, nFreq, nChan] = size(PSD_all);

%% 4. Per-window labels and trial information

Ck           = zeros(nWin, 1);
CFbk         = zeros(nWin, 1);
isTrialStart = false(nWin, 1);

trialInfo = struct([]);
nTrials = 0;

cfIdxAll = find(EVENT_all.TYP == cfEvent);

for k = 1:numel(cfIdxAll)
    cfIdx   = cfIdxAll(k);
    cfStart = EVENT_all.POS(cfIdx);
    cfEnd   = cfStart + EVENT_all.DUR(cfIdx) - 1;

    cueRel = find(ismember(EVENT_all.TYP(1:cfIdx-1), classes), 1, 'last');
    if isempty(cueRel) || cfStart < 1 || cfEnd > nWin
        continue;
    end

    trueClass = EVENT_all.TYP(cueRel);

    CFbk(cfStart:cfEnd) = cfEvent;
    Ck(cfStart:cfEnd)   = trueClass;
    isTrialStart(cfStart) = true;

    nTrials = nTrials + 1;
    trialInfo(nTrials).start = cfStart;
    trialInfo(nTrials).stop  = cfEnd;
    trialInfo(nTrials).class = trueClass;
end

fprintf('--- Test data ---\n');
fprintf('Windows: %d | trials: %d (feet: %d, hands: %d)\n', ...
    nWin, nTrials, sum([trialInfo.class] == classFeet), sum([trialInfo.class] == classHands));

%% 5. Features and decoder prediction

F    = log(reshape(PSD_all, nWin, nFreq * nChan));
Fsel = F(:, decoder.selIdx);

[Gk, pp] = predict(decoder.Model, Fsel);
% pp columns follow decoder.classes = [feet hands]: pp(:,1)=P(feet), pp(:,2)=P(hands)

%% 6. Single-sample accuracy on the test set

maskCF = (CFbk == cfEvent);

ssOverall = 100 * mean(Gk(maskCF) == Ck(maskCF));
ssFeet    = 100 * mean(Gk(maskCF & Ck == classFeet)  == classFeet);
ssHands   = 100 * mean(Gk(maskCF & Ck == classHands) == classHands);

fprintf('\n--- Single-sample accuracy (test set) ---\n');
fprintf('Overall: %.2f %% | hands: %.2f %% | feet: %.2f %%\n', ssOverall, ssHands, ssFeet);

figure('Name', 'Lab09 - Single sample accuracy on test set', 'Color', 'w');
ssValues = [ssOverall, ssHands, ssFeet];
bar(ssValues, 'FaceColor', [0.10 0.45 0.90]);
text(1:3, ssValues + 2, compose('%.1f%%', ssValues), ...
    'HorizontalAlignment', 'center', 'Color', 'k', 'FontWeight', 'bold');
set(gca, 'XTickLabel', {'overall', 'both hands', 'both feet'}, ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
ylabel('accuracy [%]', 'Color', 'k');
ylim([0 100]);
title('Single sample accuracy on test set', 'Color', 'k');
grid on;

%% 7. Control framework - exponential evidence accumulation

D = 0.5 * ones(nWin, 2);

for w = 2:nWin
    if isTrialStart(w)
        D(w, :) = [0.5 0.5];                       % reset at the start of a trial
    else
        D(w, :) = alpha * D(w-1, :) + (1 - alpha) * pp(w, :);
    end
end

%% 8. Per-trial decision by threshold crossing

predForced  = zeros(nTrials, 1);   % a decision is always forced (without rejection)
predDecided = nan(nTrials, 1);     % NaN if the evidence never crosses a threshold
trueClasses = [trialInfo.class]';

for t = 1:nTrials
    seg = D(trialInfo(t).start:trialInfo(t).stop, 1);   % integrated P(feet)

    iHigh = find(seg >= thHigh, 1, 'first');
    iLow  = find(seg <= thLow,  1, 'first');

    if isempty(iHigh) && isempty(iLow)
        % Never crossed: rejected; forced decision from the final evidence
        predForced(t) = (seg(end) >= 0.5) * classFeet + (seg(end) < 0.5) * classHands;
    else
        if isempty(iLow) || (~isempty(iHigh) && iHigh <= iLow)
            decision = classFeet;
        else
            decision = classHands;
        end
        predDecided(t) = decision;
        predForced(t)  = decision;
    end
end

decided = ~isnan(predDecided);

accWithout = 100 * mean(predForced == trueClasses);
accWith    = 100 * mean(predDecided(decided) == trueClasses(decided));
rejRate    = 100 * mean(~decided);

fprintf('\n--- Trial-based accuracy ---\n');
fprintf('Without rejection: %.2f %% (all %d trials)\n', accWithout, nTrials);
fprintf('With rejection:    %.2f %% (%d trials, %.1f %% rejected)\n', ...
    accWith, sum(decided), rejRate);

%% 9. Figure - Evidence accumulation on one trial

exampleTrial = min(exampleTrial, nTrials);
seg   = trialInfo(exampleTrial).start:trialInfo(exampleTrial).stop;
xWin  = 1:numel(seg);
trueCl = trialInfo(exampleTrial).class;
trueName = 'both feet';
if trueCl == classHands; trueName = 'both hands'; end

figure('Name', 'Lab09 - Evidence accumulation', 'Color', 'w');
hold on;
hRaw = plot(xWin, pp(seg, 1), 'o', 'MarkerEdgeColor', [0.4 0.4 0.4], 'MarkerSize', 4);
hInt = plot(xWin, D(seg, 1), 'k-', 'LineWidth', 1.8);
yline(thHigh, '--', 'Th_1', 'Color', [0.85 0.2 0.2], 'LineWidth', 1);
yline(thLow,  '--', 'Th_2', 'Color', [0.85 0.2 0.2], 'LineWidth', 1);
yline(0.5, ':', 'Color', [0.6 0.6 0.6]);
hold off;

set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
ylim([0 1]);
xlabel('sample (window)', 'Color', 'k');
ylabel('probability / control', 'Color', 'k');
title(sprintf('Trial %d/%d - Class %s', exampleTrial, nTrials, trueName), 'Color', 'k');
legend([hRaw hInt], {'raw prob (P feet)', 'integrated prob'}, 'Location', 'best', 'TextColor', 'k');

%% 10. Figure - Trial accuracy without and with rejection

figure('Name', 'Lab09 - Trial accuracy', 'Color', 'w');
trialAcc = [accWithout, accWith];
bar(trialAcc, 'FaceColor', [0.10 0.45 0.90]);
text(1:2, trialAcc + 2, compose('%.1f%%', trialAcc), ...
    'HorizontalAlignment', 'center', 'Color', 'k', 'FontWeight', 'bold');
set(gca, 'XTickLabel', {'without rejection', 'with rejection'}, ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
ylabel('accuracy [%]', 'Color', 'k');
ylim([0 100]);
title('Trial accuracy on test set', 'Color', 'k');
grid on;

%% 11. Final summary

fprintf('\n--- Lab09 script 3 completed ---\n');
fprintf('Single-sample (overall): %.2f %%\n', ssOverall);
fprintf('Trial accuracy without rejection: %.2f %%\n', accWithout);
fprintf('Trial accuracy with rejection:    %.2f %% (%.1f %% rejected)\n', accWith, rejRate);
