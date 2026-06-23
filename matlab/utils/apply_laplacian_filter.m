function S_lap = apply_laplacian_filter(S, lapFile)
%APPLY_LAPLACIAN_FILTER Apply Laplacian spatial filter using a mask file.
%
% Inputs:
%   S        EEG data [samples x channels]
%   lapFile  Path to laplacian16.mat
%
% Outputs:
%   S_lap    Laplacian-filtered EEG data [samples x channels]
%
% Expected .mat content:
%   A variable named 'lap' with size [channels x channels].

if isempty(S)
    error('Input EEG matrix S is empty.');
end

if ~ismatrix(S)
    error('Input S must be a 2D matrix [samples x channels].');
end

if ~isfile(lapFile)
    error('Laplacian file not found: %s', lapFile);
end

data = load(lapFile);

if ~isfield(data, 'lap')
    error('The Laplacian file must contain a variable named lap.');
end

lap = data.lap;

nChannels = size(S, 2);

if ~isequal(size(lap), [nChannels, nChannels])
    error('Invalid Laplacian size. Expected [%d x %d], got [%d x %d].', ...
        nChannels, nChannels, size(lap, 1), size(lap, 2));
end

S_lap = S * lap;
end