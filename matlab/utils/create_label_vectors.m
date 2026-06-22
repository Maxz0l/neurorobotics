function labels = create_label_vectors(EVENT, nSamples)
%CREATE_LABEL_VECTORS Create sample-wise label vectors from GDF events.
%
% Neurorobotics 2025/2026
%
% Inputs:
%   EVENT    - Event structure with fields TYP, POS, DUR
%   nSamples - Total number of samples in the signal
%
% Outputs:
%   labels - structure containing:
%       Tk     - trial index vector
%       Fk     - fixation vector, original event code 786
%       Ak     - cue vector, original event codes 771 / 773
%       AkPlot - cue vector for visualization: 1 = feet, 2 = hands
%       CFk    - continuous feedback vector, original event code 781
%       Xk     - hit/miss vector, original event codes 897 / 898

%% 1. Event codes

TRIAL_START = 1;
FIXATION    = 786;
BOTH_FEET   = 771;
BOTH_HANDS  = 773;
FEEDBACK    = 781;
HIT         = 897;
MISS        = 898;

%% 2. Initialize label vectors

Tk     = zeros(nSamples, 1);
Fk     = zeros(nSamples, 1);
Ak     = zeros(nSamples, 1);
AkPlot = zeros(nSamples, 1);
CFk    = zeros(nSamples, 1);
Xk     = zeros(nSamples, 1);

%% 3. Basic checks

if ~isfield(EVENT, 'TYP') || ~isfield(EVENT, 'POS') || ~isfield(EVENT, 'DUR')
    error('EVENT must contain TYP, POS, and DUR fields.');
end

typ = EVENT.TYP(:);
pos = EVENT.POS(:);
dur = EVENT.DUR(:);

if ~(numel(typ) == numel(pos) && numel(pos) == numel(dur))
    error('EVENT.TYP, EVENT.POS, and EVENT.DUR must have the same length.');
end

%% 4. Fill label vectors

trialCounter = 0;

for iEvent = 1:numel(typ)

    eventType  = typ(iEvent);
    eventStart = pos(iEvent);
    eventEnd   = pos(iEvent) + dur(iEvent) - 1;

    % Safety clipping
    eventStart = max(1, eventStart);
    eventEnd   = min(nSamples, eventEnd);

    if eventStart > nSamples || eventEnd < 1
        continue;
    end

    switch eventType

        case TRIAL_START
            trialCounter = trialCounter + 1;
            Tk(eventStart:eventEnd) = trialCounter;

        case FIXATION
            Fk(eventStart:eventEnd) = FIXATION;

            if trialCounter > 0
                Tk(eventStart:eventEnd) = trialCounter;
            end

        case BOTH_FEET
            Ak(eventStart:eventEnd) = BOTH_FEET;
            AkPlot(eventStart:eventEnd) = 1;

            if trialCounter > 0
                Tk(eventStart:eventEnd) = trialCounter;
            end

        case BOTH_HANDS
            Ak(eventStart:eventEnd) = BOTH_HANDS;
            AkPlot(eventStart:eventEnd) = 2;

            if trialCounter > 0
                Tk(eventStart:eventEnd) = trialCounter;
            end

        case FEEDBACK
            CFk(eventStart:eventEnd) = FEEDBACK;

            if trialCounter > 0
                Tk(eventStart:eventEnd) = trialCounter;
            end

        case {HIT, MISS}
            Xk(eventStart:eventEnd) = eventType;

            if trialCounter > 0
                Tk(eventStart:eventEnd) = trialCounter;
            end
    end
end

%% 5. Store output

labels.Tk     = Tk;
labels.Fk     = Fk;
labels.Ak     = Ak;
labels.AkPlot = AkPlot;
labels.CFk    = CFk;
labels.Xk     = Xk;

end