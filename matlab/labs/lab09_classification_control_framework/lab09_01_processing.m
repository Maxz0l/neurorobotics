%% Lab09 - Script 1 - Spectrogram processing (online evaluation runs)
% Neurorobotics 2025/2026
%
% Goal:
%   Process the ONLINE evaluation GDF files exactly like Lab07 script 1
%   (Laplacian -> proc_spectrogram -> frequency selection -> event
%   conversion -> save one .mat per run).
%
% The three OFFLINE calibration runs were already processed in Lab07
% (lab07_01_processing.m), so only the four online runs are processed here.
% The processing is identical, so the .mat are fully compatible.
%
% This is script 1 of Lab09. Script 2 (training) uses the offline .mat,
% script 3 (testing) uses these online .mat.

clear; close all; clc;

%% 1. Configuration

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

rawDataDir       = fullfile(projectRoot, 'data', 'raw');
externalDir      = fullfile(projectRoot, 'data', 'external');
processedDataDir = fullfile(projectRoot, 'data', 'processed');
utilsDir         = fullfile(projectRoot, 'utils');

addpath(utilsDir);

if ~isfolder(processedDataDir)
    mkdir(processedDataDir);
end

% Online evaluation runs only (offline runs already processed in Lab07)
files = {
    'ah7.20170613.170929.online.mi.mi_bhbf.ema.gdf'
    'ah7.20170613.171649.online.mi.mi_bhbf.dynamic.gdf'
    'ah7.20170613.172356.online.mi.mi_bhbf.dynamic.gdf'
    'ah7.20170613.173100.online.mi.mi_bhbf.ema.gdf'
};

lapFile = fullfile(externalDir, 'laplacian16.mat');

% Spectrogram parameters (same as Lab07 / Lab08, for compatible .mat)
wlength = 0.5;      % s - external window length
wshift  = 0.0625;   % s - external window shift
pshift  = 0.25;     % s - internal PSD window shift
mlength = 1;        % s - moving average length

% Frequency subset to keep
freqMin  = 4;       % Hz
freqMax  = 48;      % Hz
freqStep = 2;       % Hz
selectedFreqs = freqMin:freqStep:freqMax;

% Event position/duration conversion (samples -> PSD windows)
winconv = 'backward';

%% 2. Load the Laplacian mask once

lapData = load(lapFile);

if ~isfield(lapData, 'lap')
    error('The Laplacian file must contain a variable named lap.');
end

lap = lapData.lap;

%% 3. Process each online GDF file separately

for iFile = 1:numel(files)

    gdfName = files{iFile};
    gdfPath = fullfile(rawDataDir, gdfName);

    fprintf('\n=== Processing file %d/%d: %s ===\n', iFile, numel(files), gdfName);

    %% 3.1 Load the GDF file (EEG and trigger are separated)

    [sEEG, ~, h] = load_gdf_file(gdfPath);

    samplerate = h.SampleRate;

    %% 3.2 Apply the Laplacian spatial filter

    s_lap = sEEG * lap;   % [samples x channels]

    %% 3.3 Compute the PSD over time (spectrogram)

    [PSD, f] = proc_spectrogram(s_lap, wlength, wshift, pshift, samplerate, mlength);

    %% 3.4 Select the meaningful frequency subset (nearest grid frequencies)

    freqIdx = arrayfun(@(x) find(abs(f - x) == min(abs(f - x)), 1), selectedFreqs);
    freqIdx = unique(freqIdx, 'stable');

    freqs = f(freqIdx);
    PSD   = PSD(:, freqIdx, :);

    %% 3.5 Convert event positions and durations to PSD windows

    winshiftSamples = wshift  * samplerate;
    wlengthSamples  = wlength * samplerate;

    EVENT = struct();
    EVENT.TYP = h.EVENT.TYP(:);
    EVENT.POS = proc_pos2win(h.EVENT.POS(:), winshiftSamples, winconv, wlengthSamples);
    EVENT.DUR = floor(h.EVENT.DUR(:) / winshiftSamples);

    %% 3.6 Save the processed data (.mat with the same name as the GDF)

    [~, baseName] = fileparts(gdfName);
    matPath = fullfile(processedDataDir, [baseName '.mat']);

    cfg = struct();
    cfg.gdfName    = gdfName;
    cfg.samplerate = samplerate;
    cfg.wlength    = wlength;
    cfg.wshift     = wshift;
    cfg.pshift     = pshift;
    cfg.mlength    = mlength;
    cfg.winconv    = winconv;
    cfg.freqMin    = freqMin;
    cfg.freqMax    = freqMax;
    cfg.freqStep   = freqStep;

    save(matPath, 'PSD', 'freqs', 'EVENT', 'samplerate', 'cfg', '-v7.3');

    %% 3.7 Console summary for this file

    fprintf('PSD size:        %d windows x %d frequencies x %d channels\n', ...
        size(PSD, 1), size(PSD, 2), size(PSD, 3));
    fprintf('Events:          %d\n', numel(EVENT.TYP));
    fprintf('Saved to:        %s\n', matPath);
end

fprintf('\n--- Lab09 script 1 completed: %d online files processed ---\n', numel(files));
