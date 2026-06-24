%% Assignment 1 - grand_average  (Analysis 1)
% Neurorobotics 2025/2026
%
% Grand average analysis on the whole population (and representative subjects):
%   - population Fisher score feature map  -> most relevant features
%   - population mu/beta ERD/ERS topographies (activity vs fixation reference)
%   - per-subject discriminability ranking -> representative subjects
%
% Uses the OFFLINE (calibration) runs, which are the cleanest (cue-correct
% feedback). Reuses concat_processed_runs, create_window_labels,
% compute_fisher_score.

clear; close all; clc;

cfg = assignment1_config();

nSub  = numel(cfg.subjects);
muBins   = find(cfg.freq.selected >= cfg.bands.mu(1)   & cfg.freq.selected <= cfg.bands.mu(2));
betaBins = find(cfg.freq.selected >= cfg.bands.beta(1) & cfg.freq.selected <= cfg.bands.beta(2));

% Storage across subjects
fisherAll = [];                                   % [nSub x nFeatures]
topoMu   = struct('feet', [], 'hands', []);       % [nSub x nChan]
topoBeta = struct('feet', [], 'hands', []);
subjDiscrim = zeros(nSub, 1);

%% 1. Per-subject computation (offline runs)

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

    [Ck, CFbk, trials] = create_window_labels(EVENT, nWin, ...
        cfg.events.fixation, cfg.classes, cfg.events.cf);

    %% 1a. Fisher feature map (log PSD on continuous-feedback windows)

    F = log(reshape(PSD, nWin, nFreq * nChan));
    maskCF = (CFbk == cfg.events.cf);
    fisher = compute_fisher_score(F(maskCF, :), Ck(maskCF));   % [1 x nFeatures]

    fisherAll(iSub, :) = fisher; %#ok<AGROW>
    subjDiscrim(iSub)  = max(fisher);

    %% 1b. Band ERD/ERS topography (mu, beta), activity vs fixation reference

    bandPowerMu   = squeeze(mean(PSD(:, muBins, :), 2));    % [nWin x nChan]
    bandPowerBeta = squeeze(mean(PSD(:, betaBins, :), 2));

    nTrials   = numel(trials);
    clsTrials = [trials.class]';
    erdMu   = zeros(nTrials, nChan);
    erdBeta = zeros(nTrials, nChan);

    for j = 1:nTrials
        tt = trials(j);
        refMu = mean(bandPowerMu(tt.fixStart:tt.fixStop, :), 1);
        actMu = mean(bandPowerMu(tt.cfStart:tt.cfStop, :), 1);
        erdMu(j, :) = 10 * log10(actMu ./ refMu);   % ERD/ERS in dB (log band-power ratio)

        refBeta = mean(bandPowerBeta(tt.fixStart:tt.fixStop, :), 1);
        actBeta = mean(bandPowerBeta(tt.cfStart:tt.cfStop, :), 1);
        erdBeta(j, :) = 10 * log10(actBeta ./ refBeta);
    end

    topoMu.feet(iSub, :)    = mean(erdMu(clsTrials == cfg.events.feet, :), 1);    %#ok<AGROW>
    topoMu.hands(iSub, :)   = mean(erdMu(clsTrials == cfg.events.hands, :), 1);   %#ok<AGROW>
    topoBeta.feet(iSub, :)  = mean(erdBeta(clsTrials == cfg.events.feet, :), 1);  %#ok<AGROW>
    topoBeta.hands(iSub, :) = mean(erdBeta(clsTrials == cfg.events.hands, :), 1); %#ok<AGROW>

    fprintf('Subject %-4s | trials feet/hands: %d/%d | peak Fisher: %.3f\n', ...
        subj.id, sum(clsTrials == cfg.events.feet), sum(clsTrials == cfg.events.hands), ...
        subjDiscrim(iSub));
end

%% 2. Population averages

fisherPop = mean(fisherAll, 1);                 % [1 x nFeatures]

featFreqIdx = mod((1:numel(fisherPop)) - 1, nFreq) + 1;
featChanIdx = floor(((1:numel(fisherPop)) - 1) / nFreq) + 1;

[~, ranking] = sort(fisherPop, 'descend');
selIdx = ranking(1:cfg.decode.nSelected);

fprintf('\n--- Most relevant features (population) ---\n');
for i = 1:cfg.decode.nSelected
    fprintf('  %s @ %d Hz (Fisher = %.3f)\n', ...
        cfg.channels.names{featChanIdx(selIdx(i))}, ...
        cfg.freq.selected(featFreqIdx(selIdx(i))), fisherPop(selIdx(i)));
end

[~, ordSub] = sort(subjDiscrim, 'descend');
fprintf('\n--- Representative subjects (by peak Fisher) ---\n');
fprintf('  Most discriminable:  %s\n', cfg.subjects(ordSub(1)).id);
fprintf('  Least discriminable: %s\n', cfg.subjects(ordSub(end)).id);

%% 3. Figure 1 - Population Fisher feature map

figure('Name', 'Assignment1 - Population Fisher map', 'Color', 'w');
fmap = reshape(fisherPop, nFreq, nChan)';        % [nChan x nFreq], Fz first
imagesc(cfg.freq.selected, 1:nChan, fmap);
colormap(parula);
hold on;
for i = 1:cfg.decode.nSelected
    plot(cfg.freq.selected(featFreqIdx(selIdx(i))), featChanIdx(selIdx(i)), ...
        'o', 'MarkerEdgeColor', 'r', 'MarkerSize', 10, 'LineWidth', 1.8);
end
hold off;
set(gca, 'YTick', 1:nChan, 'YTickLabel', cfg.channels.names, ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
xlabel('Frequency [Hz]', 'Color', 'k');
ylabel('Channel', 'Color', 'k');
title('Population Fisher score (red = selected features)', 'Color', 'k');
cb = colorbar; cb.Color = 'k';

%% 4. Figure 2 - Population ERD/ERS topographies (mu, beta)

chanData = load(cfg.paths.chanFile);
if isfield(chanData, 'chanlocs16')
    chanlocs = chanData.chanlocs16;
elseif isfield(chanData, 'chanlocs')
    chanlocs = chanData.chanlocs;
else
    error('No channel location variable found in chanlocs16.mat.');
end

maps   = {mean(topoMu.feet,1),  mean(topoMu.hands,1),  mean(topoBeta.feet,1),  mean(topoBeta.hands,1)};
titles = {'\mu - feet', '\mu - hands', '\beta - feet', '\beta - hands'};

% Robust symmetric color limit (98th percentile of |values|) so a single
% noisy channel/subject does not dominate the scale
cLim = prctile(abs([maps{:}]), 98);
cLim = max(cLim, 0.5);

fprintf('\nERD/ERS topography [dB] ranges (population):\n');
for p = 1:4
    fprintf('  %-14s min %.2f  max %.2f  mean %.2f\n', titles{p}, ...
        min(maps{p}), max(maps{p}), mean(maps{p}));
end
fprintf('Color limit: +/- %.2f dB\n', cLim);

figure('Name', 'Assignment1 - Population ERD/ERS topographies', 'Color', 'w');
for p = 1:4
    subplot(2, 2, p);
    topoplot(maps{p}, chanlocs, 'maplimits', [-cLim cLim], 'electrodes', 'on');
    title(titles{p}, 'Color', 'k');
    cb = colorbar; cb.Color = 'k';
    cb.Label.String = 'ERD/ERS [dB]';
end
colormap(jet);
sgtitle('Population ERD/ERS during activity (vs fixation) [dB]', 'Color', 'k');

%% 5. Final summary

fprintf('\n--- grand_average completed (%d subjects) ---\n', nSub);
