function [logPower, filteredData, cfg] = compute_log_bandpower(data, sampleRate, freqBand, varargin)
%COMPUTE_LOG_BANDPOWER Compute logarithmic band power from EEG data.
%
% Neurorobotics 2025/2026
%
% This function is kept for backward compatibility with Lab04 and Lab05.
% Internally, it calls compute_bandpower() with ApplyLog = true.

[logPower, filteredData, cfg] = compute_bandpower( ...
    data, sampleRate, freqBand, ...
    'ApplyLog', true, ...
    varargin{:});

end