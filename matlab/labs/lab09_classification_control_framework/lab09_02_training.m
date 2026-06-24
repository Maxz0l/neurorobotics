%% Lab09 - Script 2 - Train and save the decoder
% Neurorobotics 2025/2026
%
% Goal:
%   Train the motor-imagery decoder on the OFFLINE calibration runs and save
%   it (with the selected features) so that script 3 can apply it to the
%   online evaluation runs.
%
% Pipeline:
%   load offline .mat -> concatenate -> per-window labels
%   -> features = log(PSD) -> Fisher score (continuous feedback windows)
%   -> select top features -> fitcdiscr -> save decoder

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

processedDataDir = fullfile(projectRoot, 'data', 'processed');
utilsDir         = fullfile(projectRoot, 'utils');

addpath(utilsDir);

% Calibration (offline) runs
calibrationFiles = {
    'ah7.20170613.161402.offline.mi.mi_bhbf.mat'
    'ah7.20170613.162331.offline.mi.mi_bhbf.mat'
    'ah7.20170613.162934.offline.mi.mi_bhbf.mat'
};

decoderFile = fullfile(processedDataDir, 'decoder_bhbf.mat');

% Event codes
cfEvent    = 781;   % continuous feedback (training windows)
classFeet  = 771;
classHands = 773;
classes    = [classFeet classHands];

channelNames = {'Fz','FC3','FC1','FCz','FC2','FC4','C3','C1','Cz','C2','C4', ...
                'CP3','CP1','CPz','CP2','CP4'};

nSelected   = 2;
discrimType = 'quadratic';

%% 2. Load and concatenate the calibration runs

PSD_all = [];
EVENT_all.TYP = [];
EVENT_all.POS = [];
EVENT_all.DUR = [];
winOffset = 0;
freqs = [];

for iFile = 1:numel(calibrationFiles)

    matPath = fullfile(processedDataDir, calibrationFiles{iFile});
    if ~isfile(matPath)
        error('Processed file not found: %s\nRun lab07_01_processing.m first.', matPath);
    end

    S = load(matPath);
    if iFile == 1
        freqs = S.freqs(:)';
    end

    PSD_all = cat(1, PSD_all, S.PSD);
    EVENT_all.TYP = [EVENT_all.TYP; S.EVENT.TYP(:)];
    EVENT_all.POS = [EVENT_all.POS; S.EVENT.POS(:) + winOffset];
    EVENT_all.DUR = [EVENT_all.DUR; S.EVENT.DUR(:)];
    winOffset = winOffset + size(S.PSD, 1);
end

[nWin, nFreq, nChan] = size(PSD_all);

%% 3. Per-window label vectors (class and continuous-feedback period)

Ck   = zeros(nWin, 1);
CFbk = zeros(nWin, 1);

cfIdxAll = find(EVENT_all.TYP == cfEvent);

for k = 1:numel(cfIdxAll)
    cfIdx   = cfIdxAll(k);
    cfStart = EVENT_all.POS(cfIdx);
    cfEnd   = cfStart + EVENT_all.DUR(cfIdx) - 1;

    cueRel = find(ismember(EVENT_all.TYP(1:cfIdx-1), classes), 1, 'last');
    if isempty(cueRel) || cfEnd > nWin
        continue;
    end

    CFbk(cfStart:cfEnd) = cfEvent;
    Ck(cfStart:cfEnd)   = EVENT_all.TYP(cueRel);
end

%% 4. Feature matrix (log PSD) and feature mapping

F = log(reshape(PSD_all, nWin, nFreq * nChan));

nFeatures   = nFreq * nChan;
featFreqIdx = mod((1:nFeatures) - 1, nFreq) + 1;
featChanIdx = floor(((1:nFeatures) - 1) / nFreq) + 1;

%% 5. Fisher score and feature selection (continuous-feedback windows)

maskCF = (CFbk == cfEvent);
fisherOverall = compute_fisher_score(F(maskCF, :), Ck(maskCF));

[~, ranking] = sort(fisherOverall, 'descend');
selIdx = ranking(1:nSelected);

selNames = arrayfun(@(k) sprintf('%s@%dHz', channelNames{featChanIdx(k)}, freqs(featFreqIdx(k))), ...
    selIdx, 'UniformOutput', false);

fprintf('--- Selected features ---\n');
for i = 1:nSelected
    fprintf('  %d) %s (Fisher = %.3f)\n', i, selNames{i}, fisherOverall(selIdx(i)));
end

%% 6. Train the decoder

Ftrain = F(maskCF, selIdx);
ytrain = Ck(maskCF);

Model = fitcdiscr(Ftrain, ytrain, 'DiscrimType', discrimType);

% Training accuracy (sanity check)
trainAcc = 100 * mean(predict(Model, Ftrain) == ytrain);
fprintf('\nTraining accuracy (calibration): %.2f %%\n', trainAcc);

%% 7. Save the decoder

decoder = struct();
decoder.Model        = Model;
decoder.selIdx       = selIdx;
decoder.selNames     = selNames;
decoder.featChanIdx  = featChanIdx;
decoder.featFreqIdx  = featFreqIdx;
decoder.freqs        = freqs;
decoder.channelNames = channelNames;
decoder.classes      = classes;       % [feet hands], matches Model.ClassNames order
decoder.discrimType  = discrimType;
decoder.nSelected    = nSelected;

save(decoderFile, 'decoder', '-v7.3');

fprintf('\n--- Lab09 script 2 completed ---\n');
fprintf('Decoder saved to: %s\n', decoderFile);
