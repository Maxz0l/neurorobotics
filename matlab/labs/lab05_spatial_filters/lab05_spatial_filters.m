%% Lab05 - Spatial filters on logarithmic band power
% Neurorobotics 2025/2026
% Goal:
%   Compare logarithmic band power features without spatial filtering,
%   with CAR filtering, and with Laplacian filtering.
%
% Inputs:
%   - Offline GDF files in matlab/data/raw/
%   - laplacian16.mat in matlab/data/external/
%
% Outputs:
%   - Figures comparing logarithmic band power for each spatial filter
%
% Scientific idea:
%   Spatial filters can improve motor imagery features by reducing
%   common activity and emphasizing local sensorimotor patterns.

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

rawDataDir = fullfile(projectRoot, 'data', 'raw');
externalDir = fullfile(projectRoot, 'data', 'external');
utilsDir = fullfile(projectRoot, 'utils');

addpath(utilsDir);

files = {
    'ah7.20170613.161402.offline.mi.mi_bhbf.gdf'
    'ah7.20170613.162331.offline.mi.mi_bhbf.gdf'
    'ah7.20170613.162934.offline.mi.mi_bhbf.gdf'
};

lapFile = fullfile(externalDir, 'laplacian16.mat');

% Event codes
EVENT_FIXATION = 786;
EVENT_FEET = 771;
EVENT_HANDS = 773;

% Frequency bands
muBand = [8 12];
betaBand = [18 22];

% Selected motor channels
% Typical 16-channel layout:
% 7 = C3, 9 = Cz, 11 = C4
selectedChannels = [7 9 11];
selectedChannelNames = {'C3', 'Cz', 'C4'};

% Spatial filtering methods
spatialMethods = {'none', 'car', 'laplacian'};
spatialTitles = {'No spatial filter', 'CAR filter', 'Laplacian filter'};

%% 2. Load and concatenate GDF files

[S_eeg_all, ~, EVENT_all, ~, ~, sampleRate] = concat_gdf_runs(files, rawDataDir);

fprintf('Loaded EEG data: %d samples x %d channels\n', ...
    size(S_eeg_all, 1), size(S_eeg_all, 2));
fprintf('Sample rate: %d Hz\n', sampleRate);

%% 3. Process each spatial filtering condition

for iMethod = 1:numel(spatialMethods)

    method = spatialMethods{iMethod};
    methodTitle = spatialTitles{iMethod};

    fprintf('\nProcessing spatial method: %s\n', methodTitle);

    %% 3.1 Apply spatial filtering

    switch method
        case 'none'
            S_spatial = S_eeg_all;

        case 'car'
            S_spatial = apply_car_filter(S_eeg_all);

        case 'laplacian'
            S_spatial = apply_laplacian_filter(S_eeg_all, lapFile);

        otherwise
            error('Unknown spatial filtering method: %s', method);
    end

    %% 3.2 Compute logarithmic band power

    [logPowerMu, ~] = compute_log_bandpower(S_spatial, sampleRate, muBand);
    [logPowerBeta, ~] = compute_log_bandpower(S_spatial, sampleRate, betaBand);

    %% 3.3 Extract trials from fixation to end of feedback

    [TrialsMu, Ck, ~] = extract_trials( ...
        logPowerMu, EVENT_all, selectedChannels, sampleRate, EVENT_FIXATION);

    [TrialsBeta, ~, ~] = extract_trials( ...
        logPowerBeta, EVENT_all, selectedChannels, sampleRate, EVENT_FIXATION);

    timeTrial = (0:size(TrialsMu, 1)-1) / sampleRate;

    %% 3.4 Separate classes

    idxFeet = Ck == EVENT_FEET;
    idxHands = Ck == EVENT_HANDS;

    if sum(idxFeet) == 0 || sum(idxHands) == 0
        error('No trials found for one of the MI classes. Check Ck and event codes.');
    end

    %% 3.5 Average log-bandpower by class

    muFeetMean = mean(TrialsMu(:, :, idxFeet), 3, 'omitnan');
    muHandsMean = mean(TrialsMu(:, :, idxHands), 3, 'omitnan');

    betaFeetMean = mean(TrialsBeta(:, :, idxFeet), 3, 'omitnan');
    betaHandsMean = mean(TrialsBeta(:, :, idxHands), 3, 'omitnan');

    %% 3.6 Visualization - Mu and Beta bands in the same figure

    figure('Name', ['Lab05 - ' methodTitle]);

    for ch = 1:numel(selectedChannels)

        %% Mu band subplot

        subplot(2, 3, ch);
        hold on;

        plot(timeTrial, muHandsMean(:, ch), 'LineWidth', 1.5);
        plot(timeTrial, muFeetMean(:, ch), 'LineWidth', 1.5);

        xline(3, '--k');
        xline(4, '--k');

        grid on;
        xlabel('Time [s]');
        ylabel('Log power');

        title(sprintf('\\mu band - %s', selectedChannelNames{ch}));

        if ch == 1
            legend('Hands', 'Feet', 'Location', 'best');
        end

        %% Beta band subplot

        subplot(2, 3, ch + 3);
        hold on;

        plot(timeTrial, betaHandsMean(:, ch), 'LineWidth', 1.5);
        plot(timeTrial, betaFeetMean(:, ch), 'LineWidth', 1.5);

        xline(3, '--k');
        xline(4, '--k');

        grid on;
        xlabel('Time [s]');
        ylabel('Log power');

        title(sprintf('\\beta band - %s', selectedChannelNames{ch}));

        if ch == 1
            legend('Hands', 'Feet', 'Location', 'best');
        end

    end

    sgtitle(sprintf('Lab05 - %s', methodTitle));

end