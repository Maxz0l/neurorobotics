%% Lab03 - GDF data concatenation
% Neurorobotics 2025/2026
% Goal:
%   Load several offline GDF runs, concatenate EEG signals and events,
%   then create label vectors and extract trials.
%
% Inputs:
%   Offline GDF files stored in matlab/data/raw/
%
% Outputs:
%   Concatenated EEG matrix
%   Concatenated trigger vector
%   Concatenated EVENT structure
%   Label vectors and extracted trials

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

nFiles = numel(files);

% Event codes
TRIAL_START = 1;
BOTH_FEET   = 771;
BOTH_HANDS  = 773;

%% 2. Load and concatenate data

[S_eeg_all, S_trigger_all, EVENT_all, Rk, headers, sampleRate] = ...
    concat_gdf_runs(files, rawDataDir);

%% 3. Basic checks

assert(length(Rk) == size(S_eeg_all, 1), ...
    'Rk length mismatch.');

assert(size(S_trigger_all, 1) == size(S_eeg_all, 1), ...
    'Trigger length mismatch.');

fprintf('\nLab03 checks passed.\n');

%% 4. Create label vectors

labels = create_label_vectors(EVENT_all, size(S_eeg_all, 1));

Tk     = labels.Tk;
Fk     = labels.Fk;
Ak     = labels.Ak;
AkPlot = labels.AkPlot;
CFk    = labels.CFk;
Xk     = labels.Xk;

%% 5. Visualization of label vectors

time = (0:size(S_eeg_all, 1)-1) / sampleRate;

figure('Name', 'Lab03 - Label vectors on concatenated data');

subplot(5,1,1);
plot(time, Tk);
ylabel('Tk');
title('Trial index');
grid on;

subplot(5,1,2);
plot(time, Fk);
ylabel('Fk');
title('Fixation periods');
grid on;

subplot(5,1,3);
plot(time, AkPlot);
ylabel('Ak');
title('Cue periods: 1 = both feet, 2 = both hands');
yticks([0 1 2]);
yticklabels({'0', 'Feet', 'Hands'});
grid on;

subplot(5,1,4);
plot(time, CFk);
ylabel('CFk');
title('Continuous feedback periods');
grid on;

subplot(5,1,5);
plot(time, Xk);
ylabel('Xk');
xlabel('Time [s]');
title('Hit / miss periods');
grid on;

figure('Name', 'Lab03 - Run index vector');
plot(time, Rk);
xlabel('Time [s]');
ylabel('Run index');
title('Rk - Run index over concatenated data');
yticks(1:nFiles);
grid on;

%% 6. Trial extraction

% Lab03: extract full trials from event 1 to the end of continuous feedback.
startEvent = TRIAL_START;

[Trials, Ck, trialInfo] = extract_trials( ...
    S_eeg_all, EVENT_all, [], sampleRate, startEvent);

fprintf('\nTrial extraction completed.\n');
fprintf('Trials size: [%d samples x %d channels x %d trials]\n', ...
    size(Trials, 1), size(Trials, 2), size(Trials, 3));

fprintf('Cue distribution:\n');
fprintf('Cue %d - Both feet : %d trials\n', BOTH_FEET, sum(Ck == BOTH_FEET));
fprintf('Cue %d - Both hands: %d trials\n', BOTH_HANDS, sum(Ck == BOTH_HANDS));

disp('First extracted trials:');
disp(trialInfo(1:min(10, height(trialInfo)), :));

%% 7. Single trial visualization

channelIdx = 3;

trialFeet  = find(Ck == BOTH_FEET, 1, 'first');
trialHands = find(Ck == BOTH_HANDS, 1, 'first');

trialTime = (0:size(Trials, 1)-1) / sampleRate;

figure('Name', 'Lab03 - Single trials by cue');

subplot(2,1,1);
plot(trialTime, Trials(:, channelIdx, trialFeet));
xlabel('Time [s]');
ylabel('Amplitude [\muV]');
title(sprintf('Single trial - Cue %d / Both feet - Channel %d', ...
    BOTH_FEET, channelIdx));
grid on;

subplot(2,1,2);
plot(trialTime, Trials(:, channelIdx, trialHands));
xlabel('Time [s]');
ylabel('Amplitude [\muV]');
title(sprintf('Single trial - Cue %d / Both hands - Channel %d', ...
    BOTH_HANDS, channelIdx));
grid on;

%% 8. Grand average visualization

avgFeet  = mean(Trials(:, :, Ck == BOTH_FEET), 3);
avgHands = mean(Trials(:, :, Ck == BOTH_HANDS), 3);

figure('Name', 'Lab03 - Grand averages by cue');

subplot(2,1,1);
plot(trialTime, avgFeet(:, channelIdx));
xlabel('Time [s]');
ylabel('Amplitude [\muV]');
title(sprintf('Grand average - Cue %d / Both feet - Channel %d', ...
    BOTH_FEET, channelIdx));
grid on;

subplot(2,1,2);
plot(trialTime, avgHands(:, channelIdx));
xlabel('Time [s]');
ylabel('Amplitude [\muV]');
title(sprintf('Grand average - Cue %d / Both hands - Channel %d', ...
    BOTH_HANDS, channelIdx));
grid on;