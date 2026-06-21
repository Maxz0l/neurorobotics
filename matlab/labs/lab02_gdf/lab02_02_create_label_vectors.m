%% Lab02 - Create label vectors from GDF events
% Neurorobotics 2025/2026
% Goal:
%   Create sample-wise label vectors from GDF events.
%
% Inputs:
%   data/raw/ah7.20170613.161402.offline.mi.mi_bhbf.gdf
%
% Outputs:
%   Label vectors:
%   - Tk  : trial index
%   - Fk  : fixation period
%   - Ak  : cue period
%   - CFk : continuous feedback period
%   - Xk  : hit/miss period

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

dataDir = fullfile(projectRoot, 'data', 'raw');

filename = fullfile(dataDir, ...
    'ah7.20170613.161402.offline.mi.mi_bhbf.gdf');

assert(isfile(filename), ...
    'GDF file not found. Check that the file is in matlab/data/raw.');

% Event codes
EVENT_TRIAL_START = 1;
EVENT_FIXATION    = 786;
EVENT_BOTH_FEET   = 771;
EVENT_BOTH_HANDS  = 773;
EVENT_FEEDBACK    = 781;
EVENT_HIT         = 897;
EVENT_MISS        = 898;

%% 2. Load data

[sEEG, sTrigger, h] = load_gdf_file(filename);

fs = h.SampleRate;
nSamples = size(sEEG, 1);

fprintf('Loaded file:\n%s\n\n', filename);
fprintf('EEG data size: %d samples x %d EEG channels\n', size(sEEG, 1), size(sEEG, 2));
fprintf('Trigger channel size: %d samples x 1\n', size(sTrigger, 1));
fprintf('Sample rate: %.2f Hz\n', fs);
fprintf('Number of events: %d\n', numel(h.EVENT.TYP));

%% 3. Create label vectors

labels = create_label_vectors(h.EVENT, nSamples);

Tk  = labels.Tk;
Fk  = labels.Fk;
Ak  = labels.Ak;
CFk = labels.CFk;
Xk  = labels.Xk;

fprintf('Number of detected trials: %d\n', labels.nTrials);

%% 4. Visualization / save results

time = (0:nSamples-1) / fs;

figure('Name', 'Lab02 - Label vectors');

subplot(5, 1, 1);
plot(time, Tk);
grid on;
ylabel('Tk');
title('Trial index');

subplot(5, 1, 2);
plot(time, Fk);
grid on;
ylabel('Fk');
title('Fixation periods');

subplot(5, 1, 3);
plot(time, Ak);
grid on;
ylabel('Ak');
title('Cue periods');

subplot(5, 1, 4);
plot(time, CFk);
grid on;
ylabel('CFk');
title('Continuous feedback periods');

subplot(5, 1, 5);
plot(time, Xk);
grid on;
ylabel('Xk');
xlabel('Time [s]');
title('Hit / miss periods');

sgtitle('Sample-wise label vectors');