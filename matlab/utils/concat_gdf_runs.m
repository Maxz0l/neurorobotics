function [S_eeg_all, S_trigger_all, EVENT_all, Rk, headers, sampleRate] = concat_gdf_runs(files, rawDataDir)
%CONCAT_GDF_RUNS Load and concatenate several offline GDF runs.
%
% Neurorobotics 2025/2026
%
% Inputs:
%   files      - Cell array containing GDF filenames
%   rawDataDir - Directory containing the GDF files
%
% Outputs:
%   S_eeg_all      - Concatenated EEG data [samples x 16 channels]
%   S_trigger_all  - Concatenated trigger channel [samples x 1]
%   EVENT_all      - Concatenated EVENT structure with corrected POS
%   Rk             - Run index vector [samples x 1]
%   headers        - Cell array containing the header of each file
%   sampleRate     - Sampling rate in Hz

    %% 1. Input checks

    if nargin < 1 || isempty(files)
        error('concat_gdf_runs:MissingFiles', ...
              'A non-empty cell array of GDF filenames must be provided.');
    end

    if nargin < 2 || isempty(rawDataDir)
        error('concat_gdf_runs:MissingRawDataDir', ...
              'The raw data directory must be provided.');
    end

    if ~iscell(files)
        error('concat_gdf_runs:InvalidFilesInput', ...
              'files must be a cell array of filenames.');
    end

    if ~isfolder(rawDataDir)
        error('concat_gdf_runs:InvalidRawDataDir', ...
              'Raw data directory not found: %s', rawDataDir);
    end

    %% 2. Initialization

    nFiles = numel(files);

    S_eeg_all = [];
    S_trigger_all = [];

    EVENT_all.TYP = [];
    EVENT_all.POS = [];
    EVENT_all.DUR = [];

    Rk = [];

    headers = cell(nFiles, 1);

    sampleOffset = 0;
    sampleRate = [];

    %% 3. Load and concatenate each run

    for iFile = 1:nFiles

        filename = fullfile(rawDataDir, files{iFile});
        fprintf('Loading file %d/%d: %s\n', iFile, nFiles, files{iFile});

        [sEEG, sTrigger, h] = load_gdf_file(filename);

        headers{iFile} = h;

        % Check consistency across files
        if iFile == 1
            sampleRate = h.SampleRate;
            nEEGChannels = size(sEEG, 2);
        else
            assert(h.SampleRate == sampleRate, ...
                'concat_gdf_runs:SamplingRateMismatch', ...
                'Sampling rate mismatch in file %d.', iFile);

            assert(size(sEEG, 2) == nEEGChannels, ...
                'concat_gdf_runs:ChannelCountMismatch', ...
                'EEG channel count mismatch in file %d.', iFile);
        end

        % Concatenate EEG data
        S_eeg_all = [S_eeg_all; sEEG];

        % Concatenate trigger channel
        S_trigger_all = [S_trigger_all; sTrigger];

        % Create run index vector
        Rk = [Rk; iFile * ones(size(sEEG, 1), 1)];

        % Concatenate events with corrected positions
        EVENT_all.TYP = [EVENT_all.TYP; h.EVENT.TYP(:)];
        EVENT_all.POS = [EVENT_all.POS; h.EVENT.POS(:) + sampleOffset];
        EVENT_all.DUR = [EVENT_all.DUR; h.EVENT.DUR(:)];

        % Update offset for next run
        sampleOffset = sampleOffset + size(sEEG, 1);
    end

    %% 4. Final checks

    assert(size(S_trigger_all, 1) == size(S_eeg_all, 1), ...
        'concat_gdf_runs:TriggerLengthMismatch', ...
        'Trigger vector length does not match EEG data length.');

    assert(length(Rk) == size(S_eeg_all, 1), ...
        'concat_gdf_runs:RkLengthMismatch', ...
        'Rk length does not match EEG data length.');

    assert(numel(EVENT_all.TYP) == numel(EVENT_all.POS) && ...
           numel(EVENT_all.POS) == numel(EVENT_all.DUR), ...
        'concat_gdf_runs:EventLengthMismatch', ...
        'EVENT fields TYP, POS, and DUR do not have the same length.');

    %% 5. Console summary

    fprintf('\nConcatenation completed.\n');
    fprintf('Total samples: %d\n', size(S_eeg_all, 1));
    fprintf('Number of EEG channels: %d\n', size(S_eeg_all, 2));
    fprintf('Trigger vector size: [%d samples x %d channel]\n', ...
        size(S_trigger_all, 1), size(S_trigger_all, 2));
    fprintf('Sampling rate: %.1f Hz\n', sampleRate);
    fprintf('Number of events: %d\n', numel(EVENT_all.TYP));

    disp('Event types found:');
    disp(unique(EVENT_all.TYP));

end