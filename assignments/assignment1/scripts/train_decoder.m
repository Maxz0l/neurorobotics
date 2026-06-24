%% Assignment 1 - train_decoder  (Analysis 2a: calibration)
% Neurorobotics 2025/2026
%
% For each subject, using ONLY the offline (calibration) runs:
%   load -> features (log PSD) -> Fisher score -> select features
%   -> train an LDA/QDA decoder (fitcdiscr) -> save one decoder per subject
%
% Also estimates the offline single-sample accuracy by 5-fold cross-validation
% (honest estimate, since training and testing on the same offline data by
% resubstitution would be optimistic).
%
% Output: data/processed/assignment1/<subject>/decoder.mat
%
% Reuses concat_processed_runs, create_window_labels, compute_fisher_score.

clear; close all; clc;

cfg = assignment1_config();

nSub = numel(cfg.subjects);
offlineAcc = nan(nSub, 3);   % [overall feet hands] per subject

%% Per-subject calibration

for iSub = 1:nSub

    subj = cfg.subjects(iSub);

    % Processed .mat paths for this subject's offline runs
    offlineMat = cell(numel(subj.offline), 1);
    for k = 1:numel(subj.offline)
        [~, base] = fileparts(subj.offline{k});
        offlineMat{k} = fullfile(cfg.paths.processed, subj.id, [base '.mat']);
    end

    [PSD, EVENT, ~, freqs, ~] = concat_processed_runs(offlineMat);
    [nWin, nFreq, nChan] = size(PSD);

    [Ck, CFbk, ~] = create_window_labels(EVENT, nWin, ...
        cfg.events.fixation, cfg.classes, cfg.events.cf);

    % Feature matrix (log PSD) and feature -> channel/frequency mapping
    F = log(reshape(PSD, nWin, nFreq * nChan));
    nFeatures   = nFreq * nChan;
    featFreqIdx = mod((1:nFeatures) - 1, nFreq) + 1;
    featChanIdx = floor(((1:nFeatures) - 1) / nFreq) + 1;

    % Fisher score on the continuous-feedback windows -> select top features
    maskCF = (CFbk == cfg.events.cf);
    Xcf = F(maskCF, :);
    ycf = Ck(maskCF);

    fisher = compute_fisher_score(Xcf, ycf);
    [~, ranking] = sort(fisher, 'descend');
    selIdx = ranking(1:cfg.decode.nSelected);

    selNames = arrayfun(@(k) sprintf('%s@%dHz', cfg.channels.names{featChanIdx(k)}, ...
        freqs(featFreqIdx(k))), selIdx, 'UniformOutput', false);

    % Selected feature matrix
    Xsel = Xcf(:, selIdx);

    % Final decoder (trained on all offline continuous-feedback windows)
    Model = fitcdiscr(Xsel, ycf, 'DiscrimType', cfg.decode.discrimType);

    % Offline single-sample accuracy by 5-fold cross-validation
    cvModel = fitcdiscr(Xsel, ycf, 'DiscrimType', cfg.decode.discrimType, ...
        'KFold', cfg.decode.kfold);
    yhat = kfoldPredict(cvModel);

    offlineAcc(iSub, 1) = 100 * mean(yhat == ycf);
    offlineAcc(iSub, 2) = 100 * mean(yhat(ycf == cfg.events.feet)  == cfg.events.feet);
    offlineAcc(iSub, 3) = 100 * mean(yhat(ycf == cfg.events.hands) == cfg.events.hands);

    % Save the decoder
    decoder = struct();
    decoder.subjectId    = subj.id;
    decoder.Model        = Model;
    decoder.selIdx       = selIdx;
    decoder.selNames     = selNames;
    decoder.featChanIdx  = featChanIdx;
    decoder.featFreqIdx  = featFreqIdx;
    decoder.freqs        = freqs;
    decoder.channelNames = cfg.channels.names;
    decoder.classes      = cfg.classes;
    decoder.discrimType  = cfg.decode.discrimType;
    decoder.nSelected    = cfg.decode.nSelected;
    decoder.offlineAcc   = offlineAcc(iSub, :);   % [overall feet hands]

    save(fullfile(cfg.paths.processed, subj.id, 'decoder.mat'), 'decoder', '-v7.3');

    fprintf('Subject %-4s | features: %s | offline CV acc: %.1f%% (feet %.1f / hands %.1f)\n', ...
        subj.id, strjoin(selNames, ', '), ...
        offlineAcc(iSub, 1), offlineAcc(iSub, 2), offlineAcc(iSub, 3));
end

%% Summary

fprintf('\n--- Offline single-sample accuracy (5-fold CV) ---\n');
fprintf('Mean over %d subjects: %.1f%% (feet %.1f / hands %.1f)\n', ...
    nSub, mean(offlineAcc(:,1)), mean(offlineAcc(:,2)), mean(offlineAcc(:,3)));
[bestAcc, bestI]   = max(offlineAcc(:, 1));
[worstAcc, worstI] = min(offlineAcc(:, 1));
fprintf('Best:  %s (%.1f%%)\n', cfg.subjects(bestI).id, bestAcc);
fprintf('Worst: %s (%.1f%%)\n', cfg.subjects(worstI).id, worstAcc);

fprintf('\n--- train_decoder completed: %d decoders saved ---\n', nSub);
