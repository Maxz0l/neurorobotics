%% Assignment 1 - evaluate_online  (Analysis 2b: evaluation)
% Neurorobotics 2025/2026
%
% For each subject, apply the calibrated decoder to the ONLINE (evaluation)
% runs and compute:
%   - single-sample accuracy (online)
%   - evidence accumulation (exponential smoothing) -> per-trial decision
%   - trial accuracy without and with rejection
%   - average time to deliver a command
%
% The online results are saved to data/processed/assignment1/online_results.mat
% for results_summary. One example evidence-accumulation figure is shown.
%
% Reuses concat_processed_runs, create_window_labels.

clear; close all; clc;

cfg = assignment1_config();

thLow  = cfg.control.thLow;     % used only for the example figure thresholds
thHigh = cfg.control.thHigh;
wshift = cfg.spectro.wshift;    % seconds per window step (figure x-axis)

exampleSubject = 'aj1';         % subject used for the example figure

nSub = numel(cfg.subjects);
R = struct('id', {}, 'ssOnline', {}, 'trialWithout', {}, 'trialWith', {}, ...
           'rejRate', {}, 'avgTime', {});

exampleData = struct();

%% Per-subject online evaluation

for iSub = 1:nSub

    subj = cfg.subjects(iSub);

    % Load the calibrated decoder
    decFile = fullfile(cfg.paths.processed, subj.id, 'decoder.mat');
    if ~isfile(decFile)
        error('Decoder not found for %s. Run train_decoder.m first.', subj.id);
    end
    S = load(decFile, 'decoder');
    decoder = S.decoder;

    % Processed .mat paths for this subject's online runs
    onlineMat = cell(numel(subj.online), 1);
    for k = 1:numel(subj.online)
        [~, base] = fileparts(subj.online{k});
        onlineMat{k} = fullfile(cfg.paths.processed, subj.id, [base '.mat']);
    end

    [PSD, EVENT, ~, ~, ~] = concat_processed_runs(onlineMat);
    [nWin, nFreq, nChan] = size(PSD);

    [Ck, CFbk, trials] = create_window_labels(EVENT, nWin, ...
        cfg.events.fixation, cfg.classes, cfg.events.cf);

    % Features and prediction
    F    = log(reshape(PSD, nWin, nFreq * nChan));
    Fsel = F(:, decoder.selIdx);
    [Gk, pp] = predict(decoder.Model, Fsel);   % pp(:,1)=P(feet), pp(:,2)=P(hands)

    %% Single-sample accuracy (continuous-feedback windows)

    maskCF = (CFbk == cfg.events.cf);
    ssOverall = 100 * mean(Gk(maskCF) == Ck(maskCF));
    ssFeet    = 100 * mean(Gk(maskCF & Ck == cfg.events.feet)  == cfg.events.feet);
    ssHands   = 100 * mean(Gk(maskCF & Ck == cfg.events.hands) == cfg.events.hands);

    %% Control framework: evidence accumulation + per-trial decision

    [predForced, predDecided, timeCmd, D] = apply_control_framework(pp, trials, cfg);
    decided = ~isnan(predDecided);
    trueCl  = [trials.class]';

    %% Store results

    R(iSub).id           = subj.id;
    R(iSub).ssOnline     = [ssOverall ssFeet ssHands];
    R(iSub).trialWithout = 100 * mean(predForced == trueCl);
    R(iSub).trialWith    = 100 * mean(predDecided(decided) == trueCl(decided));
    R(iSub).rejRate      = 100 * mean(~decided);
    R(iSub).avgTime      = mean(timeCmd(decided), 'omitnan');

    fprintf(['Subject %-4s | online SS: %.1f%% | trial: %.1f%% (no rej) / ' ...
             '%.1f%% (rej %.0f%%) | t_cmd: %.2fs\n'], ...
        subj.id, ssOverall, R(iSub).trialWithout, R(iSub).trialWith, ...
        R(iSub).rejRate, R(iSub).avgTime);

    % Keep data for the example figure
    if strcmp(subj.id, exampleSubject)
        exampleData.pp = pp; exampleData.D = D; exampleData.trials = trials;
        exampleData.predDecided = predDecided; exampleData.trueCl = trueCl;
        exampleData.timeCmd = timeCmd; exampleData.decided = decided;
    end
end

%% Aggregate summary

ssAll    = vertcat(R.ssOnline);
fprintf('\n--- Online results (mean over %d subjects) ---\n', nSub);
fprintf('Single-sample: %.1f%% (feet %.1f / hands %.1f)\n', ...
    mean(ssAll(:,1)), mean(ssAll(:,2)), mean(ssAll(:,3)));
fprintf('Trial accuracy: %.1f%% (no rejection) / %.1f%% (with rejection)\n', ...
    mean([R.trialWithout]), mean([R.trialWith]));
fprintf('Mean rejection rate: %.1f%% | mean time to command: %.2fs\n', ...
    mean([R.rejRate]), mean([R.avgTime], 'omitnan'));

save(fullfile(cfg.paths.processed, 'online_results.mat'), 'R', '-v7.3');

%% Example figure - evidence accumulation on one trial

if isfield(exampleData, 'D')
    trials = exampleData.trials;
    % Pick a correctly-decided, representative (median time-to-command) trial
    correct = exampleData.decided & (exampleData.predDecided == exampleData.trueCl);
    cand = find(correct);
    [~, mi] = min(abs(exampleData.timeCmd(cand) - median(exampleData.timeCmd(cand), 'omitnan')));
    tEx = cand(mi);
    seg   = trials(tEx).cfStart:trials(tEx).cfStop;
    x     = (0:numel(seg)-1) * wshift;
    raw   = exampleData.pp(seg, 1);
    integ = exampleData.D(seg, 1);

    trueName = 'both feet';
    if trials(tEx).class == cfg.events.hands, trueName = 'both hands'; end
    decName = 'feet';
    if exampleData.predDecided(tEx) == cfg.events.hands, decName = 'hands'; end

    tCmd     = exampleData.timeCmd(tEx);
    crossIdx = min(round(tCmd / wshift) + 1, numel(integ));

    figure('Name', 'Assignment1 - Evidence accumulation example', 'Color', 'w');
    hold on;
    hRaw = plot(x, raw,   'o', 'MarkerEdgeColor', [0.6 0.6 0.6], 'MarkerSize', 4);
    hInt = plot(x, integ, 'k-', 'LineWidth', 2);
    yline(thHigh, '--', 'cross up \rightarrow feet',  'Color', [0.10 0.45 0.90], ...
        'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
    yline(thLow,  '--', 'cross down \rightarrow hands', 'Color', [0.90 0.40 0.10], ...
        'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
    yline(0.5, ':', 'Color', [0.6 0.6 0.6]);
    xline(tCmd, ':', 'Color', [0.20 0.70 0.20]);
    hDec = plot(tCmd, integ(crossIdx), 'p', 'MarkerSize', 15, ...
        'MarkerFaceColor', [0.20 0.70 0.20], 'MarkerEdgeColor', 'k');
    hold off;

    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'FontSize', 11);
    ylim([0 1]);
    xlabel('time from feedback onset [s]', 'Color', 'k');
    ylabel('P(feet)  /  accumulated evidence', 'Color', 'k');
    title(sprintf('%s  |  true: %s  \\rightarrow  decided: %s at %.2f s', ...
        exampleSubject, trueName, decName, tCmd), 'Color', 'k');
    lgd = legend([hRaw hInt hDec], ...
        {'raw P(feet) per window', 'integrated evidence D(t)', 'decision (threshold reached)'}, ...
        'Location', 'south', 'TextColor', 'k');
    lgd.Color = 'w';   % white legend background (readable under MATLAB dark theme)
end

fprintf('\n--- evaluate_online completed ---\n');
