%% Assignment 1 - process_all_runs
% Neurorobotics 2025/2026
%
% Process every GDF run of every subject (offline + online):
%   load GDF -> Laplacian -> proc_spectrogram -> frequency selection
%   -> convert event POS/DUR to windows -> save one .mat per run
%
% Output: data/processed/assignment1/<subject>/<run>.mat
%
% Same processing as Lab07/Lab09 script 1, generalized to all subjects/runs
% discovered by assignment1_config. Already-processed runs are skipped, so the
% script can be re-run safely (set forceReprocess = true to recompute).

clear; close all; clc;

cfg = assignment1_config();

forceReprocess = false;

%% Load the Laplacian mask once

lapData = load(cfg.paths.lapFile);
if ~isfield(lapData, 'lap')
    error('The Laplacian file must contain a variable named lap.');
end
lap = lapData.lap;

selectedFreqs = cfg.freq.selected;

%% Process each subject / run

nProcessed = 0;
nSkipped   = 0;

for iSub = 1:numel(cfg.subjects)

    subj   = cfg.subjects(iSub);
    outDir = fullfile(cfg.paths.processed, subj.id);
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    runs = [subj.offline(:); subj.online(:)];

    fprintf('\n=== Subject %s (%d runs) ===\n', subj.id, numel(runs));

    for iRun = 1:numel(runs)

        gdfPath = runs{iRun};
        [~, baseName] = fileparts(gdfPath);
        matPath = fullfile(outDir, [baseName '.mat']);

        if ~forceReprocess && isfile(matPath)
            nSkipped = nSkipped + 1;
            fprintf('  [skip] %s\n', baseName);
            continue;
        end

        if contains(gdfPath, '.offline.')
            runType = 'offline';
        else
            runType = 'online';
        end

        % Load + Laplacian
        [sEEG, ~, h] = load_gdf_file(gdfPath);
        samplerate = h.SampleRate;
        s_lap = sEEG * lap;

        % Spectrogram
        [PSD, f] = proc_spectrogram(s_lap, cfg.spectro.wlength, cfg.spectro.wshift, ...
            cfg.spectro.pshift, samplerate, cfg.spectro.mlength);

        % Frequency selection (nearest grid frequencies)
        freqIdx = arrayfun(@(x) find(abs(f - x) == min(abs(f - x)), 1), selectedFreqs);
        freqIdx = unique(freqIdx, 'stable');
        freqs = f(freqIdx);
        PSD   = PSD(:, freqIdx, :);

        % Event conversion to PSD windows
        winshiftSamples = cfg.spectro.wshift  * samplerate;
        wlengthSamples  = cfg.spectro.wlength * samplerate;
        EVENT = struct();
        EVENT.TYP = h.EVENT.TYP(:);
        EVENT.POS = proc_pos2win(h.EVENT.POS(:), winshiftSamples, cfg.spectro.winconv, wlengthSamples);
        EVENT.DUR = floor(h.EVENT.DUR(:) / winshiftSamples);

        % Metadata (subject, run type, day)
        nameParts = split(baseName, '.');
        meta = struct('subject', subj.id, 'runType', runType, ...
            'date', nameParts{2}, 'gdfName', [baseName '.gdf']);

        save(matPath, 'PSD', 'freqs', 'EVENT', 'samplerate', 'meta', '-v7.3');

        nProcessed = nProcessed + 1;
        fprintf('  [ok]   %s | %s | %d win x %d freq x %d ch\n', ...
            baseName, runType, size(PSD, 1), size(PSD, 2), size(PSD, 3));
    end
end

fprintf('\n--- process_all_runs completed: %d processed, %d skipped ---\n', ...
    nProcessed, nSkipped);
