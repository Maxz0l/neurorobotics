function [Trials, Ck, trialInfo] = extract_trials(S, EVENT, channels, sampleRate, startEvent)
%EXTRACT_TRIALS Extract MI trials from EEG data.
%
% Neurorobotics 2025/2026
%
% Inputs:
%   S           - Data matrix [samples x channels]
%   EVENT       - Event structure with fields TYP, POS, DUR
%   channels    - Channels to extract. Use [] to keep all channels.
%   sampleRate  - Sampling rate in Hz
%   startEvent  - Event used as trial start, e.g. 1 or 786
%
% Outputs:
%   Trials      - Extracted trials [samples x channels x trials]
%   Ck          - Cue label for each trial [trials x 1]
%   trialInfo   - Table with trial metadata

    %% 1. Default arguments

    if nargin < 3 || isempty(channels)
        channels = 1:size(S, 2);
    end

    if nargin < 4 || isempty(sampleRate)
        sampleRate = 512;
    end

    if nargin < 5 || isempty(startEvent)
        startEvent = 786;
    end

    %% 2. Event codes

    FIXATION    = 786;
    BOTH_FEET   = 771;
    BOTH_HANDS  = 773;
    FEEDBACK    = 781;

    CUE_CLASSES = [BOTH_FEET, BOTH_HANDS];

    %% 3. Prepare event vectors

    typ = EVENT.TYP(:);
    pos = EVENT.POS(:);
    dur = EVENT.DUR(:);

    startIdx = find(typ == startEvent);

    if isempty(startIdx)
        error('No start events found for event type %d.', startEvent);
    end

    %% 4. Extract trial boundaries

    trialStarts = [];
    fixationStarts = [];
    cueStarts = [];
    feedbackStarts = [];
    trialEnds = [];
    cueLabels = [];

    for iTrialCandidate = 1:numel(startIdx)

        idxStart = startIdx(iTrialCandidate);

        if iTrialCandidate < numel(startIdx)
            nextStartIdx = startIdx(iTrialCandidate + 1);
            searchRange = idxStart:nextStartIdx-1;
        else
            searchRange = idxStart:numel(typ);
        end

        fixIdxLocal = searchRange(typ(searchRange) == FIXATION);
        cueIdxLocal = searchRange(ismember(typ(searchRange), CUE_CLASSES));
        cfIdxLocal  = searchRange(typ(searchRange) == FEEDBACK);

        if isempty(fixIdxLocal) || isempty(cueIdxLocal) || isempty(cfIdxLocal)
            warning('Skipping trial candidate %d: missing fixation, cue, or feedback.', ...
                iTrialCandidate);
            continue;
        end

        fixIdx = fixIdxLocal(1);
        cueIdx = cueIdxLocal(1);
        cfIdx  = cfIdxLocal(1);

        trialStart = pos(idxStart);
        trialEnd   = pos(cfIdx) + dur(cfIdx) - 1;

        if trialStart < 1 || trialEnd > size(S, 1)
            warning('Skipping trial candidate %d: trial boundaries exceed data length.', ...
                iTrialCandidate);
            continue;
        end

        trialStarts(end+1, 1)    = trialStart;
        fixationStarts(end+1, 1) = pos(fixIdx);
        cueStarts(end+1, 1)      = pos(cueIdx);
        feedbackStarts(end+1, 1) = pos(cfIdx);
        trialEnds(end+1, 1)      = trialEnd;
        cueLabels(end+1, 1)      = typ(cueIdx);
    end

    if isempty(cueLabels)
        error('No valid trials were extracted.');
    end

    %% 5. Force common trial length

    trialLengths = trialEnds - trialStarts + 1;
    nSamplesTrial = min(trialLengths);

    if numel(unique(trialLengths)) ~= 1
        warning(['Trials have different lengths. ', ...
                 'All trials will be truncated to %d samples = %.3f s.'], ...
                 nSamplesTrial, nSamplesTrial / sampleRate);
    end

    %% 6. Build trial matrix

    nTrials = numel(cueLabels);
    nChannels = numel(channels);

    Trials = zeros(nSamplesTrial, nChannels, nTrials);

    for iTrial = 1:nTrials
        idx = trialStarts(iTrial):(trialStarts(iTrial) + nSamplesTrial - 1);
        Trials(:, :, iTrial) = S(idx, channels);
    end

    Ck = cueLabels;

    %% 7. Trial information table

    trialInfo = table( ...
        (1:nTrials)', ...
        trialStarts, ...
        fixationStarts, ...
        cueStarts, ...
        feedbackStarts, ...
        trialEnds, ...
        trialLengths, ...
        cueLabels, ...
        'VariableNames', {'Trial', 'StartSample', 'FixationSample', ...
                          'CueSample', 'FeedbackSample', 'EndSample', ...
                          'LengthSamples', 'Cue'} ...
    );

end