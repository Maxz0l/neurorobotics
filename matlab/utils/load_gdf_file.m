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

assert(isfile(filename), ...
    'GDF file not found: %s', filename);

[s, h] = sload(filename);

assert(size(s, 2) >= 17, ...
    'Expected at least 17 channels: 16 EEG + 1 trigger.');

eegChannels = 1:16;
triggerChannel = 17;

sEEG = s(:, eegChannels);
sTrigger = s(:, triggerChannel);

end