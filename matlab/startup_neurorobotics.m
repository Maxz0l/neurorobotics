%% startup_neurorobotics
% Neurorobotics 2025/2026
% Goal:
% Add only the required project paths and external toolboxes for the course.
%
% Important:
% This script does not permanently modify the MATLAB path.
% Run it manually at the beginning of each MATLAB session.

clear; clc;

%% 1. Project root

projectRoot = fileparts(mfilename('fullpath'));

fprintf('[config] Project root:\n%s\n\n', projectRoot);

%% 2. Add project folders

addpath(fullfile(projectRoot, 'utils'));
addpath(genpath(fullfile(projectRoot, 'labs')));

fprintf('[config] Added project folders: utils, labs\n');

%% 3. Add EEGLAB

eeglabPath = fullfile(projectRoot, 'toolboxes', 'eeglab');

if isfolder(eeglabPath)
    addpath(genpath(eeglabPath));
    fprintf('[config] Added EEGLAB:\n%s\n', eeglabPath);
else
    warning('[config] EEGLAB folder not found:\n%s', eeglabPath);
end

%% 4. Add BIOSIG

biosigRoot = fullfile(projectRoot, 'toolboxes', 'biosig');

biosigFileAccess = fullfile(biosigRoot, 'biosig', 'biosig', 't200_FileAccess');
biosigArtifact = fullfile(biosigRoot, 'biosig', 'biosig', 't250_ArtifactPreProcessingQualityControl');

if isfolder(biosigFileAccess)
    addpath(genpath(biosigFileAccess));
    fprintf('[config] Added BIOSIG FileAccess:\n%s\n', biosigFileAccess);
else
    warning('[config] BIOSIG t200_FileAccess not found:\n%s', biosigFileAccess);
end

if isfolder(biosigArtifact)
    addpath(genpath(biosigArtifact));
    fprintf('[config] Added BIOSIG ArtifactPreProcessingQualityControl:\n%s\n', biosigArtifact);
else
    warning('[config] BIOSIG t250_ArtifactPreProcessingQualityControl not found:\n%s', biosigArtifact);
end

%% 5. Verification

fprintf('\n[check] Looking for sload:\n');
disp(which('sload'));

fprintf('[check] Looking for eeglab:\n');
disp(which('eeglab'));

fprintf('\n[config] Neurorobotics MATLAB environment loaded.\n');