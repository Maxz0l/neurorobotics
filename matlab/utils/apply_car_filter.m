function S_car = apply_car_filter(S)
%APPLY_CAR_FILTER Apply Common Average Reference spatial filter.
%
% Inputs:
%   S      EEG data [samples x channels]
%
% Outputs:
%   S_car  CAR-filtered EEG data [samples x channels]
%
% Principle:
%   At each time sample, subtract the average across all EEG channels.

if isempty(S)
    error('Input EEG matrix S is empty.');
end

if ~ismatrix(S)
    error('Input S must be a 2D matrix [samples x channels].');
end

channelMean = mean(S, 2);
S_car = S - channelMean;
end