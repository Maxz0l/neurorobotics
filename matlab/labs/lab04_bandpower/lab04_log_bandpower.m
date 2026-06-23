%% Lab04 - MI BMI Logarithmic Band Power
% Neurorobotics 2025/2026
%
% Goal:
%   Compute logarithmic band power in mu and beta bands from offline GDF runs.
%
% Inputs:
%   Offline GDF files stored in matlab/data/raw/
%
% Outputs:
%   Figures showing:
%       - raw EEG and filtered signals for one trial
%       - averaged log-bandpower for both MI classes
%
% Notes:
%   Heavy files (.gdf, .mat, .set, .fdt) must not be committed to Git.

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

rawDataDir = fullfile(projectRoot, 'data', 'raw');
utilsDir   = fullfile(projectRoot, 'utils');

addpath(utilsDir);

files = {
    'ah7.20170613.161402.offline.mi.mi_bhbf.gdf'
    'ah7.20170613.162331.offline.mi.mi_bhbf.gdf'
    'ah7.20170613.162934.offline.mi.mi_bhbf.gdf'
};

muBand   = [8 12];
betaBand = [18 30];

filterOrder = 4;
movingWindowSec = 1;

selectedChannels = [7 9 11];  % Selected EEG channels for visualization
trialStartEvent = 786;        % Fixation cross

%% 2. Load data

[S_eeg_all, ~, EVENT_all, ~, ~, sampleRate] = ...
    concat_gdf_runs(files, rawDataDir);

%% 3. Create label vectors

labels = create_label_vectors(EVENT_all, size(S_eeg_all, 1)); %#ok<NASGU>

%% 4. Compute logarithmic band power

[logPowerMu, filteredMu, ~] = compute_log_bandpower( ...
    S_eeg_all, sampleRate, muBand, ...
    'FilterOrder', filterOrder, ...
    'MovingWindowSec', movingWindowSec);

[logPowerBeta, filteredBeta, ~] = compute_log_bandpower( ...
    S_eeg_all, sampleRate, betaBand, ...
    'FilterOrder', filterOrder, ...
    'MovingWindowSec', movingWindowSec);

%% 5. Extract trials

[rawTrials, Ck, trialInfo] = extract_trials( ...
    S_eeg_all, EVENT_all, selectedChannels, sampleRate, trialStartEvent);

[muTrials, CkMu, ~] = extract_trials( ...
    logPowerMu, EVENT_all, selectedChannels, sampleRate, trialStartEvent);

[betaTrials, CkBeta, ~] = extract_trials( ...
    logPowerBeta, EVENT_all, selectedChannels, sampleRate, trialStartEvent);

[filteredMuTrials, CkFilteredMu, ~] = extract_trials( ...
    filteredMu, EVENT_all, selectedChannels, sampleRate, trialStartEvent);

[filteredBetaTrials, CkFilteredBeta, ~] = extract_trials( ...
    filteredBeta, EVENT_all, selectedChannels, sampleRate, trialStartEvent);

if ~isequal(Ck, CkMu, CkBeta, CkFilteredMu, CkFilteredBeta)
    error('Trial labels are inconsistent between raw, filtered, and log-power trials.');
end

%% 6. Create trial time vector

timeTrial = (0:size(rawTrials, 1)-1) / sampleRate;

%% 7. Estimate trial event timings

firstTrial = trialInfo(1, :);

cueRelSample      = firstTrial.CueSample      - firstTrial.StartSample + 1;
feedbackRelSample = firstTrial.FeedbackSample - firstTrial.StartSample + 1;

cueTime      = (cueRelSample - 1) / sampleRate;
feedbackTime = (feedbackRelSample - 1) / sampleRate;

%% 8. Visualize raw and filtered signals for one trial

trialIdx = find(Ck == 773, 1, 'first');  % First both-hands trial

figure('Name', 'Lab04 - Raw and filtered signals');

for chIdx = 1:numel(selectedChannels)

    channelNumber = selectedChannels(chIdx);

    % Raw EEG
    subplot(3, numel(selectedChannels), chIdx);
    plot(timeTrial, rawTrials(:, chIdx, trialIdx));
    grid on;
    xlabel('Time [s]');
    ylabel('Amplitude');
    title(sprintf('Raw EEG - Channel %d', channelNumber));

    % Mu filtered EEG
    subplot(3, numel(selectedChannels), chIdx + numel(selectedChannels));
    plot(timeTrial, filteredMuTrials(:, chIdx, trialIdx));
    grid on;
    xlabel('Time [s]');
    ylabel('Amplitude');
    title(sprintf('Mu [%d-%d Hz] - Channel %d', ...
        muBand(1), muBand(2), channelNumber));

    % Beta filtered EEG
    subplot(3, numel(selectedChannels), chIdx + 2*numel(selectedChannels));
    plot(timeTrial, filteredBetaTrials(:, chIdx, trialIdx));
    grid on;
    xlabel('Time [s]');
    ylabel('Amplitude');
    title(sprintf('Beta [%d-%d Hz] - Channel %d', ...
        betaBand(1), betaBand(2), channelNumber));
end

sgtitle(sprintf('Raw and filtered EEG - Trial %d - Class %d', trialIdx, Ck(trialIdx)));
%% 9. Visualize averaged log-bandpower by class

classes = [771 773];
classNames = {'Both feet', 'Both hands'};

figure('Name', 'Lab04 - Averaged log-bandpower by class');

for chIdx = 1:numel(selectedChannels)

    channelNumber = selectedChannels(chIdx);

    % Mu band
    subplot(2, numel(selectedChannels), chIdx);
    hold on;

    for c = 1:numel(classes)
        classTrials = Ck == classes(c);
        avgMu = mean(muTrials(:, chIdx, classTrials), 3);
        plot(timeTrial, avgMu, 'DisplayName', classNames{c});
    end

    xline(cueTime, '--', 'Cue', 'HandleVisibility', 'off');
    xline(feedbackTime, '--', 'Feedback', 'HandleVisibility', 'off');

    grid on;
    xlabel('Time [s]');
    ylabel('log-power');
    title(sprintf('Mu band - EEG channel %d', channelNumber));
    legend('Location', 'best');

    % Beta band
    subplot(2, numel(selectedChannels), chIdx + numel(selectedChannels));
    hold on;

    for c = 1:numel(classes)
        classTrials = Ck == classes(c);
        avgBeta = mean(betaTrials(:, chIdx, classTrials), 3);
        plot(timeTrial, avgBeta, 'DisplayName', classNames{c});
    end

    xline(cueTime, '--', 'Cue', 'HandleVisibility', 'off');
    xline(feedbackTime, '--', 'Feedback', 'HandleVisibility', 'off');

    grid on;
    xlabel('Time [s]');
    ylabel('log-power');
    title(sprintf('Beta band - EEG channel %d', channelNumber));
    legend('Location', 'best');
end