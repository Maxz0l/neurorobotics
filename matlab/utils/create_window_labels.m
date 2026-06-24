function [Ck, CFbk, trials] = create_window_labels(EVENT, nWin, fixEvent, classes, cfEvent)
%CREATE_WINDOW_LABELS Per-window labels and trial list in the PSD window domain.
%
% Neurorobotics 2025/2026
%
% Walks each trial (fixation -> cue -> continuous feedback) and builds:
%   - a class label active from the cue to the end of the continuous feedback,
%   - a continuous-feedback marker,
%   - a trial list with the fixation (reference) and feedback (activity) ranges.
%
% Inputs:
%   EVENT      struct with TYP, POS, DUR in WINDOW units
%   nWin       total number of windows
%   fixEvent   fixation-cross event code (e.g. 786)
%   classes    cue class codes, e.g. [771 773]
%   cfEvent    continuous-feedback event code (e.g. 781)
%
% Outputs:
%   Ck      [nWin x 1] class active during each trial (0 elsewhere)
%   CFbk    [nWin x 1] = cfEvent during the feedback windows (0 elsewhere)
%   trials  struct array, one per valid trial, with fields:
%             start, stop      (trial = fixation onset .. end of feedback)
%             fixStart, fixStop  (fixation / reference period)
%             cfStart, cfStop    (continuous feedback / activity period)
%             class

    Ck   = zeros(nWin, 1);
    CFbk = zeros(nWin, 1);
    trials = struct('start', {}, 'stop', {}, 'fixStart', {}, 'fixStop', {}, ...
                    'cfStart', {}, 'cfStop', {}, 'class', {});

    fixIdxAll = find(EVENT.TYP == fixEvent);

    for iFix = 1:numel(fixIdxAll)

        fixIdx = fixIdxAll(iFix);
        fixStart = EVENT.POS(fixIdx);
        fixStop  = fixStart + EVENT.DUR(fixIdx) - 1;

        afterFix = (fixIdx + 1):numel(EVENT.TYP);

        cueRel = find(ismember(EVENT.TYP(afterFix), classes), 1, 'first');
        if isempty(cueRel)
            continue;
        end
        cueIdx = afterFix(cueRel);

        afterCue = (cueIdx + 1):numel(EVENT.TYP);
        cfRel = find(EVENT.TYP(afterCue) == cfEvent, 1, 'first');
        if isempty(cfRel)
            continue;
        end
        cfIdx = afterCue(cfRel);

        cfStart = EVENT.POS(cfIdx);
        cfStop  = cfStart + EVENT.DUR(cfIdx) - 1;

        if fixStart < 1 || cfStop > nWin
            continue;
        end

        cls = EVENT.TYP(cueIdx);

        CFbk(cfStart:cfStop)  = cfEvent;
        Ck(EVENT.POS(cueIdx):cfStop) = cls;

        t = numel(trials) + 1;
        trials(t).start    = fixStart;
        trials(t).stop     = cfStop;
        trials(t).fixStart = fixStart;
        trials(t).fixStop  = fixStop;
        trials(t).cfStart  = cfStart;
        trials(t).cfStop   = cfStop;
        trials(t).class    = cls;
    end
end
