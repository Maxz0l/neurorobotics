function [PSD, EVENT, runIdx, freqs, samplerate] = concat_processed_runs(matFiles)
%CONCAT_PROCESSED_RUNS Load and concatenate processed PSD runs (window domain).
%
% Neurorobotics 2025/2026
%
% Loads several processed .mat files (each produced by the spectrogram
% processing step, containing PSD, freqs, EVENT, samplerate) and concatenates
% them along the window dimension, shifting the event positions by the
% cumulative number of windows already loaded.
%
% Inputs:
%   matFiles   Cell array of full paths to processed .mat files
%
% Outputs:
%   PSD         [windows x frequencies x channels] concatenated PSD
%   EVENT       struct with fields TYP, POS, DUR (POS shifted per run)
%   runIdx      [windows x 1] run index for each window
%   freqs       Frequency vector (from the first file)
%   samplerate  Sampling rate in Hz (from the first file)

    PSD = [];
    EVENT.TYP = [];
    EVENT.POS = [];
    EVENT.DUR = [];
    runIdx = [];
    freqs = [];
    samplerate = [];

    winOffset = 0;

    for i = 1:numel(matFiles)

        if ~isfile(matFiles{i})
            error('concat_processed_runs:FileNotFound', ...
                'Processed file not found: %s', matFiles{i});
        end

        S = load(matFiles{i});

        if i == 1
            freqs = S.freqs(:)';
            samplerate = S.samplerate;
        end

        n = size(S.PSD, 1);

        PSD = cat(1, PSD, S.PSD);
        EVENT.TYP = [EVENT.TYP; S.EVENT.TYP(:)];
        EVENT.POS = [EVENT.POS; S.EVENT.POS(:) + winOffset];
        EVENT.DUR = [EVENT.DUR; S.EVENT.DUR(:)];
        runIdx = [runIdx; i * ones(n, 1)];

        winOffset = winOffset + n;
    end
end
