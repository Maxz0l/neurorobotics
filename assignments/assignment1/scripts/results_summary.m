%% Assignment 1 - results_summary  (Analysis 2c: reporting)
% Neurorobotics 2025/2026
%
% Aggregates calibration (offline) and evaluation (online) metrics across all
% subjects and produces the report figures.
%
% Offline metrics:
%   - single-sample accuracy: 5-fold cross-validation (stored in decoder.mat)
%   - trial accuracy + time to command: decoder applied to its own offline runs
%     (RESUBSTITUTION) + control framework -> optimistic reference.
% Online metrics: held-out, from evaluate_online (online_results.mat).
%
% Reuses concat_processed_runs, create_window_labels, apply_control_framework.

clear; close all; clc;

cfg = assignment1_config();

onlineFile = fullfile(cfg.paths.processed, 'online_results.mat');
if ~isfile(onlineFile)
    error('online_results.mat not found. Run evaluate_online.m first.');
end
load(onlineFile, 'R');

nSub = numel(cfg.subjects);
ids  = {cfg.subjects.id};

ssOff = nan(nSub,1);  ssOn = nan(nSub,1);
trOffWith = nan(nSub,1);  trOffWithout = nan(nSub,1);
trOnWith  = nan(nSub,1);  trOnWithout  = nan(nSub,1);
timeOff = nan(nSub,1);  timeOn = nan(nSub,1);

%% Collect per-subject metrics

for iSub = 1:nSub

    subj = cfg.subjects(iSub);

    % Decoder + offline single-sample CV accuracy
    S = load(fullfile(cfg.paths.processed, subj.id, 'decoder.mat'), 'decoder');
    decoder = S.decoder;
    ssOff(iSub) = decoder.offlineAcc(1);

    % Offline trial metrics (resubstitution + control framework)
    offlineMat = cell(numel(subj.offline), 1);
    for k = 1:numel(subj.offline)
        [~, base] = fileparts(subj.offline{k});
        offlineMat{k} = fullfile(cfg.paths.processed, subj.id, [base '.mat']);
    end
    [PSD, EVENT, ~, ~, ~] = concat_processed_runs(offlineMat);
    [nWin, nFreq, nChan] = size(PSD);
    [~, ~, trials] = create_window_labels(EVENT, nWin, ...
        cfg.events.fixation, cfg.classes, cfg.events.cf);

    F    = log(reshape(PSD, nWin, nFreq * nChan));
    Fsel = F(:, decoder.selIdx);
    [~, pp] = predict(decoder.Model, Fsel);

    [pf, pd, tc] = apply_control_framework(pp, trials, cfg);
    decided = ~isnan(pd);
    trueCl  = [trials.class]';

    trOffWithout(iSub) = 100 * mean(pf == trueCl);
    trOffWith(iSub)    = 100 * mean(pd(decided) == trueCl(decided));
    timeOff(iSub)      = mean(tc(decided), 'omitnan');

    % Online metrics (held-out) from evaluate_online
    ridx = find(strcmp({R.id}, subj.id), 1);
    ssOn(iSub)        = R(ridx).ssOnline(1);
    trOnWith(iSub)    = R(ridx).trialWith;
    trOnWithout(iSub) = R(ridx).trialWithout;
    timeOn(iSub)      = R(ridx).avgTime;
end

%% Console summary table

fprintf('\n%-6s %7s %7s %8s %8s %7s %7s\n', ...
    'subj', 'SSoff', 'SSon', 'TRoff', 'TRon', 'Toff', 'Ton');
for iSub = 1:nSub
    fprintf('%-6s %6.1f%% %6.1f%% %7.1f%% %7.1f%% %6.2fs %6.2fs\n', ...
        ids{iSub}, ssOff(iSub), ssOn(iSub), trOffWith(iSub), trOnWith(iSub), ...
        timeOff(iSub), timeOn(iSub));
end
fprintf('%-6s %6.1f%% %6.1f%% %7.1f%% %7.1f%% %6.2fs %6.2fs\n', ...
    'MEAN', mean(ssOff), mean(ssOn), mean(trOffWith), mean(trOnWith), ...
    mean(timeOff,'omitnan'), mean(timeOn,'omitnan'));
fprintf(['(SS = single-sample %%, TR = trial %% with rejection, ' ...
         'T = time to command; offline = resubstitution)\n']);

%% Figure 1 - Single-sample accuracy: offline (CV) vs online

figure('Name', 'Assignment1 - Single-sample accuracy', 'Color', 'w');
b = bar([ssOff ssOn]);
b(1).FaceColor = [0.20 0.50 0.85];
b(2).FaceColor = [0.90 0.50 0.20];
set(gca, 'XTickLabel', ids, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
ylabel('accuracy [%]', 'Color', 'k'); ylim([0 100]);
title('Single-sample accuracy: offline (CV) vs online', 'Color', 'k');
lgd = legend({'offline (CV)', 'online'}, 'Location', 'southoutside', ...
    'Orientation', 'horizontal', 'TextColor', 'k'); lgd.Color = 'w';
grid on;

%% Figure 2 - Trial accuracy (with rejection): offline vs online

figure('Name', 'Assignment1 - Trial accuracy', 'Color', 'w');
b = bar([trOffWith trOnWith]);
b(1).FaceColor = [0.20 0.50 0.85];
b(2).FaceColor = [0.90 0.50 0.20];
set(gca, 'XTickLabel', ids, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
ylabel('trial accuracy [%]', 'Color', 'k'); ylim([0 100]);
title('Trial accuracy (with rejection): offline (resubst.) vs online', 'Color', 'k');
lgd = legend({'offline', 'online'}, 'Location', 'southoutside', ...
    'Orientation', 'horizontal', 'TextColor', 'k'); lgd.Color = 'w';
grid on;

%% Figure 3 - Average time to deliver a command

figure('Name', 'Assignment1 - Time to command', 'Color', 'w');
b = bar([timeOff timeOn]);
b(1).FaceColor = [0.20 0.50 0.85];
b(2).FaceColor = [0.90 0.50 0.20];
set(gca, 'XTickLabel', ids, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
ylabel('time to command [s]', 'Color', 'k');
title('Average time to deliver a command', 'Color', 'k');
lgd = legend({'offline', 'online'}, 'Location', 'southoutside', ...
    'Orientation', 'horizontal', 'TextColor', 'k'); lgd.Color = 'w';
grid on;

fprintf('\n--- results_summary completed (%d subjects) ---\n', nSub);
