function [logPower, filteredData, cfg] = compute_log_bandpower(data, sampleRate, freqBand, varargin)
%COMPUTE_LOG_BANDPOWER Compute logarithmic band power from EEG data.
%
% Neurorobotics 2025/2026
%
% Pipeline:
%   1. Butterworth bandpass filtering
%   2. Zero-phase filtering with filtfilt
%   3. Squaring
%   4. 1-second moving average
%   5. Logarithmic transform
%
% Inputs:
%   data        [samples x channels] EEG data
%   sampleRate  Sampling rate in Hz
%   freqBand    [low high] frequency band in Hz
%
% Optional:
%   'FilterOrder'      default = 4
%   'MovingWindowSec'  default = 1
%   'Epsilon'          default = eps
%
% Outputs:
%   logPower      [samples x channels] log-bandpower
%   filteredData  [samples x channels] bandpass-filtered data
%   cfg           configuration structure

%% 1. Parse inputs

p = inputParser;

addRequired(p, 'data', @(x) isnumeric(x) && ismatrix(x));
addRequired(p, 'sampleRate', @(x) isnumeric(x) && isscalar(x) && x > 0);
addRequired(p, 'freqBand', @(x) isnumeric(x) && numel(x) == 2 && x(1) > 0 && x(2) > x(1));

addParameter(p, 'FilterOrder', 4, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'MovingWindowSec', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Epsilon', eps, @(x) isnumeric(x) && isscalar(x) && x > 0);

parse(p, data, sampleRate, freqBand, varargin{:});

filterOrder = p.Results.FilterOrder;
movingWindowSec = p.Results.MovingWindowSec;
epsilonValue = p.Results.Epsilon;

%% 2. Design Butterworth bandpass filter

nyquistFreq = sampleRate / 2;

if freqBand(2) >= nyquistFreq
    error('Upper frequency must be lower than Nyquist frequency.');
end

normalizedBand = freqBand / nyquistFreq;

[b, a] = butter(filterOrder, normalizedBand, 'bandpass');

%% 3. Apply zero-phase filtering

filteredData = filtfilt(b, a, double(data));

%% 4. Compute power

squaredData = filteredData .^ 2;

movingWindowSamples = round(movingWindowSec * sampleRate);

powerData = movmean(squaredData, movingWindowSamples, 1);

%% 5. Log transform

logPower = log(powerData + epsilonValue);

%% 6. Save configuration

cfg = struct();
cfg.sampleRate = sampleRate;
cfg.freqBand = freqBand;
cfg.filterOrder = filterOrder;
cfg.movingWindowSec = movingWindowSec;
cfg.movingWindowSamples = movingWindowSamples;
cfg.epsilonValue = epsilonValue;
cfg.filterB = b;
cfg.filterA = a;

end