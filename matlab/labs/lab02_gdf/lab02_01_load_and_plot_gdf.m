%% Lab02 - Load and plot first GDF file
% Neurorobotics 2025/2026
% Goal:
%   Load the first GDF file, inspect EEG data and events,
%   and plot short EEG segments.
%
% Inputs:
%   data/raw/ah7.20170613.161402.offline.mi.mi_bhbf.gdf
%
% Outputs:
%   Figures showing 5 seconds of EEG data

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

dataDir = fullfile(projectRoot, 'data', 'raw');

filename = fullfile(dataDir, 'ah7.20170613.161402.offline.mi.mi_bhbf.gdf');

assert(isfile(filename), 'GDF file not found. Check that the file is in matlab/data/raw.');

%% 2. Load data

[s, h] = sload(filename);

fs = h.SampleRate;
nSamples = size(s, 1);
nChannels = size(s, 2);

fprintf('Loaded file:\n%s\n\n', filename);
fprintf('Data size: %d samples x %d channels\n', nSamples, nChannels);
fprintf('Sample rate: %.2f Hz\n', fs);
fprintf('Duration: %.2f seconds\n', nSamples / fs);
fprintf('Number of events: %d\n', numel(h.EVENT.TYP));

disp('First events:');
disp(table(h.EVENT.TYP(1:10), ...
           h.EVENT.POS(1:10), ...
           h.EVENT.DUR(1:10), ...
            'VariableNames', {'TYP', 'POS', 'DUR'}));

%% 3. Process data

durationSec = 5;
startSec = 1;

idxStart = round(startSec * fs) + 1;
idxEnd = idxStart + round(durationSec * fs) - 1;

assert(idxEnd <= nSamples, 'Selected segment exceeds signal length.');

time = (0:(idxEnd - idxStart)) / fs;

channel_1 = 1;
channel_1_to_3 = [1 2 3];

segmentOne = s(idxStart:idxEnd, channel_1);
segmentThree = s(idxStart:idxEnd, channel_1_to_3);

%% 4. Visualization / save results

figure('Name', 'Single EEG channel - 5 seconds');
plot(time, segmentOne, 'LineWidth', 1);
grid on;
xlabel('Time [s]');
ylabel('Amplitude [\muV]');
title(sprintf('Channel %d - 5 seconds EEG segment', channel_1));

figure('Name', 'Three EEG channels - 5 seconds');

yMin = min(segmentThree, [], 'all');
yMax = max(segmentThree, [], 'all');

for i = 1:numel(channel_1_to_3)
    subplot(numel(channel_1_to_3), 1, i);
    plot(time, segmentThree(:, i), 'LineWidth', 1);
    grid on;
    ylim([yMin yMax]);
    xlabel('Time [s]');
    ylabel('Amplitude [\muV]');
    title(sprintf('Channel %d', channel_1_to_3(i)));
end

sgtitle('Three EEG channels - same amplitude scale');