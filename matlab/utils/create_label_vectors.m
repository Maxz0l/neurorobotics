function labels = create_label_vectors(events, nSamples)
%CREATE_LABEL_VECTORS Create sample-wise label vectors from GDF events.
%
% Neurorobotics 2025/2026
%
% Inputs:
%   events   - h.EVENT structure from GDF header
%   nSamples - Number of samples in the signal
%
% Outputs:
%   labels - struct containing:
%       labels.Tk   : trial index
%       labels.Fk   : fixation periods
%       labels.Ak   : cue periods
%       labels.CFk  : continuous feedback periods
%       labels.Xk   : hit/miss periods
%       labels.nTrials : number of detected trials

% Event codes
EVENT_TRIAL_START = 1;
EVENT_FIXATION    = 786;
EVENT_BOTH_FEET   = 771;
EVENT_BOTH_HANDS  = 773;
EVENT_FEEDBACK    = 781;
EVENT_HIT         = 897;
EVENT_MISS        = 898;

Tk  = zeros(nSamples, 1);
Fk  = zeros(nSamples, 1);
Ak  = zeros(nSamples, 1);
CFk = zeros(nSamples, 1);
Xk  = zeros(nSamples, 1);

trialCounter = 0;

for iEvent = 1:numel(events.TYP)

    eventType = events.TYP(iEvent);
    eventPos  = events.POS(iEvent);
    eventDur  = events.DUR(iEvent);

    idxStart = eventPos;
    idxEnd = eventPos + eventDur - 1;

    idxStart = max(idxStart, 1);
    idxEnd = min(idxEnd, nSamples);

    if idxStart > idxEnd
        warning('Invalid event interval at event %d. Skipping.', iEvent);
        continue;
    end

    switch eventType

        case EVENT_TRIAL_START
            trialCounter = trialCounter + 1;
            Tk(idxStart:idxEnd) = trialCounter;

        case EVENT_FIXATION
            Fk(idxStart:idxEnd) = eventType;

        case {EVENT_BOTH_FEET, EVENT_BOTH_HANDS}
            Ak(idxStart:idxEnd) = eventType;

        case EVENT_FEEDBACK
            CFk(idxStart:idxEnd) = eventType;

        case {EVENT_HIT, EVENT_MISS}
            Xk(idxStart:idxEnd) = eventType;

        otherwise
            % Ignore other event types
    end
end

labels = struct();
labels.Tk = Tk;
labels.Fk = Fk;
labels.Ak = Ak;
labels.CFk = CFk;
labels.Xk = Xk;
labels.nTrials = trialCounter;

end