function [sEEG, sTrigger, h] = load_gdf_file(filename)
%LOAD_GDF_FILE Load a GDF file and separate EEG data from trigger channel.
%
% Neurorobotics 2025/2026
%
% Inputs:
%   filename - Full path to the GDF file
%
% Outputs:
%   sEEG      - EEG data [samples x 16 channels]
%   sTrigger  - Trigger channel [samples x 1]
%   h         - GDF header returned by sload()

%% 1. Check input file

if nargin < 1
    error('load_gdf_file:MissingInput', ...
        'A filename must be provided.');
end

if ~isfile(filename)
    error('load_gdf_file:FileNotFound', ...
        'File not found: %s', filename);
end

%% 2. Load GDF file

[s, h] = sload(filename);

%% 3. Basic checks

if ~isnumeric(s)
    error('load_gdf_file:InvalidData', ...
        'Loaded signal is not numeric.');
end

if ~isstruct(h)
    error('load_gdf_file:InvalidHeader', ...
        'Loaded header is not a structure.');
end

if ~isfield(h, 'SampleRate')
    error('load_gdf_file:MissingSampleRate', ...
        'Header does not contain SampleRate.');
end

if ~isfield(h, 'EVENT')
    error('load_gdf_file:MissingEvents', ...
        'Header does not contain EVENT structure.');
end

if size(s, 2) < 17
    error('load_gdf_file:InvalidChannelCount', ...
        'Expected at least 17 channels: 16 EEG + 1 trigger.');
end

%% 4. Separate EEG and trigger channels

sEEG = s(:, 1:16);
sTrigger = s(:, 17);

end