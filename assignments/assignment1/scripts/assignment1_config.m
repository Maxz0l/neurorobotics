function cfg = assignment1_config()
%ASSIGNMENT1_CONFIG Central configuration and dataset discovery for Assignment 1.
%
% Neurorobotics 2025/2026
%
% Returns a cfg structure shared by all Assignment 1 scripts:
%   process_all_runs, grand_average, train_decoder, evaluate_online, results_summary.
%
% It centralizes every parameter (paths, spectrogram, frequency band,
% channels, events, decoding, control framework) and discovers the subjects
% and their GDF runs by parsing the filenames:
%
%   <subject>.<date>.<time>.<offline|online>.mi.mi_bhbf[.<modality>].gdf
%
% offline runs -> calibration, online runs -> evaluation.

    %% 1. Paths
    % This file lives in assignments/assignment1/scripts/
    scriptsDir  = fileparts(mfilename('fullpath'));
    assignDir   = fileparts(scriptsDir);                 % assignments/assignment1
    projectRoot = fileparts(fileparts(assignDir));        % repo root

    cfg.paths.root      = projectRoot;
    cfg.paths.raw       = fullfile(projectRoot, 'matlab', 'data', 'raw');
    cfg.paths.processed = fullfile(projectRoot, 'matlab', 'data', 'processed', 'assignment1');
    cfg.paths.external  = fullfile(projectRoot, 'matlab', 'data', 'external');
    cfg.paths.utils     = fullfile(projectRoot, 'matlab', 'utils');
    cfg.paths.figures   = fullfile(assignDir, 'figures');
    cfg.paths.lapFile   = fullfile(cfg.paths.external, 'laplacian16.mat');
    cfg.paths.chanFile  = fullfile(cfg.paths.external, 'chanlocs16.mat');

    addpath(cfg.paths.utils);

    %% 2. Spectrogram parameters (same as Lab07/08/09 -> compatible features)
    cfg.spectro.wlength = 0.5;       % s, external window length
    cfg.spectro.wshift  = 0.0625;    % s, external window shift
    cfg.spectro.pshift  = 0.25;      % s, internal PSD window shift
    cfg.spectro.mlength = 1;         % s, moving average length
    cfg.spectro.winconv = 'backward';

    %% 3. Frequency selection
    cfg.freq.min  = 4;
    cfg.freq.max  = 48;
    cfg.freq.step = 2;
    cfg.freq.selected = cfg.freq.min:cfg.freq.step:cfg.freq.max;

    %% 4. Channels (16-channel layout)
    cfg.channels.names = {'Fz','FC3','FC1','FCz','FC2','FC4','C3','C1','Cz','C2','C4', ...
                          'CP3','CP1','CPz','CP2','CP4'};
    cfg.channels.n = numel(cfg.channels.names);

    %% 5. Frequency bands for the grand-average ERD/ERS
    cfg.bands.mu   = [8 12];
    cfg.bands.beta = [18 30];

    %% 6. Event codes
    cfg.events.fixation = 786;
    cfg.events.feet     = 771;
    cfg.events.hands    = 773;
    cfg.events.rest     = 783;
    cfg.events.cf       = 781;
    cfg.events.hit      = 897;
    cfg.events.miss     = 898;
    cfg.classes = [cfg.events.feet cfg.events.hands];

    %% 7. Decoding / feature selection
    cfg.decode.nSelected   = 2;          % number of features to select
    cfg.decode.discrimType = 'quadratic';
    cfg.decode.kfold       = 5;          % folds for offline cross-validation

    %% 8. Control framework (evidence accumulation)
    cfg.control.alpha  = 0.96;           % memory (slides convention)
    cfg.control.thLow  = 0.2;
    cfg.control.thHigh = 0.8;

    %% 9. Discover subjects and their runs (per-subject subfolders of data/raw)
    d = dir(cfg.paths.raw);
    folders = d([d.isdir] & ~startsWith({d.name}, '.'));

    cfg.subjects = struct('id', {}, 'folder', {}, 'offline', {}, 'online', {});

    for i = 1:numel(folders)

        folderPath = fullfile(cfg.paths.raw, folders(i).name);
        gdf = dir(fullfile(folderPath, '*.gdf'));
        if isempty(gdf)
            continue;
        end

        % Subject id = prefix before the first dot
        nameParts = split(gdf(1).name, '.');
        subjId = nameParts{1};

        offline = {};
        online  = {};
        for k = 1:numel(gdf)
            fpath = fullfile(folderPath, gdf(k).name);
            if contains(gdf(k).name, '.offline.')
                offline{end+1, 1} = fpath; %#ok<AGROW>
            elseif contains(gdf(k).name, '.online.')
                online{end+1, 1} = fpath; %#ok<AGROW>
            end
        end

        s = numel(cfg.subjects) + 1;
        cfg.subjects(s).id      = subjId;
        cfg.subjects(s).folder  = folderPath;
        cfg.subjects(s).offline = offline;
        cfg.subjects(s).online  = online;
    end

    fprintf('[assignment1_config] %d subjects discovered (%s)\n', ...
        numel(cfg.subjects), strjoin({cfg.subjects.id}, ', '));
end
