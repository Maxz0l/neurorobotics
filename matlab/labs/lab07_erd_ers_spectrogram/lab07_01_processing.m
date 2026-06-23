%% Lab07 - Script 1 - Spectrogram processing
% Neurorobotics 2025/2026
%
% Goal:
%   Process each offline GDF file SEPARATELY and save the result on disk:
%     load GDF
%     -> Laplacian spatial filter
%     -> PSD over time (proc_spectrogram)
%     -> select a meaningful frequency subset (4-48 Hz, step 2 Hz)
%     -> convert event POS and DUR from samples to PSD windows
%     -> save one .mat file per GDF (same name as the GDF)
%
% This is script 1 of Lab07. Script 2 (lab07_02_erd_ers.m) will load the
% .mat files, concatenate them, and compute the ERD/ERS.
%
% Rationale (see the Lab07 slides): computing the PSD with overlapping
% windows is time-consuming, so the heavy processing is done once here and
% the results are cached as .mat files for the later analysis scripts.

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

files = {
    'ah7.20170613.161402.offline.mi.mi_bhbf.gdf'
    'ah7.20170613.162331.offline.mi.mi_bhbf.gdf'
    'ah7.20170613.162934.offline.mi.mi_bhbf.gdf'
};

lapFile = fullfile(externalDir, 'laplacian16.mat');

% Spectrogram parameters (from the Lab07 document)
wlength = 0.5;      % s - length of the external (outer) window
wshift  = 0.0625;   % s - shift of the external window
pshift  = 0.25;     % s - shift of the internal PSD windows
mlength = 1;        % s - moving average length

% Frequency subset to keep from the PSD
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

%% 3. Process each GDF file separately

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
    %  proc_spectrogram(data, wlength, wshift, pshift, samplerate, mlength)
    %  PSD: [windows x frequencies x channels]

    [PSD, f] = proc_spectrogram(s_lap, wlength, wshift, pshift, samplerate, mlength);

    %% 3.4 Select the meaningful frequency subset (nearest grid frequencies)

    freqIdx = arrayfun(@(x) find(abs(f - x) == min(abs(f - x)), 1), selectedFreqs);
    freqIdx = unique(freqIdx, 'stable');

    freqs = f(freqIdx);
    PSD   = PSD(:, freqIdx, :);

    %% 3.5 Convert event positions and durations to PSD windows

    winshiftSamples = wshift  * samplerate;   % shift of the outer window [samples]
    wlengthSamples  = wlength * samplerate;   % length of the outer window [samples]

    EVENT = struct();
    EVENT.TYP = h.EVENT.TYP(:);
    EVENT.POS = proc_pos2win(h.EVENT.POS(:), winshiftSamples, winconv, wlengthSamples);
    EVENT.DUR = floor(h.EVENT.DUR(:) / winshiftSamples);   % duration in number of windows

    %% 3.6 Save the processed data (.mat with the same name as the GDF)

    [~, baseName] = fileparts(gdfName);          % strips the .gdf extension
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
    fprintf('Frequencies:     %d values (%.0f-%.0f Hz)\n', ...
        numel(freqs), freqs(1), freqs(end));
    fprintf('Events:          %d\n', numel(EVENT.TYP));
    fprintf('Saved to:        %s\n', matPath);
end

fprintf('\n--- Lab07 script 1 completed: %d files processed ---\n', numel(files));
