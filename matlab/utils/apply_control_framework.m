function [predForced, predDecided, timeCmd, D] = apply_control_framework(pp, trials, cfg)
%APPLY_CONTROL_FRAMEWORK Exponential evidence accumulation and per-trial decision.
%
% Neurorobotics 2025/2026
%
% Integrates the decoder posterior probabilities over time with exponential
% smoothing, resetting to 0.5 at the start of each trial, and makes a per-trial
% decision when the accumulated evidence crosses a threshold:
%
%   D(t) = alpha * D(t-1) + (1 - alpha) * pp(t)        (reset to 0.5 each trial)
%
% Inputs:
%   pp      [nWin x 2] posterior probabilities. pp(:,1) = P(cfg.classes(1)).
%   trials  struct array with fields cfStart, cfStop, class (window domain).
%   cfg     config with control.alpha, control.thLow, control.thHigh,
%           spectro.wshift, classes = [class1 class2].
%
% Outputs:
%   predForced   [nTrials x 1] decision for every trial (forced from the final
%                evidence when no threshold is crossed)
%   predDecided  [nTrials x 1] decision, or NaN if no threshold was crossed
%   timeCmd      [nTrials x 1] time to deliver the command [s], NaN if undecided
%   D            [nWin x 2] accumulated evidence (for plotting)

    alpha  = cfg.control.alpha;
    thLow  = cfg.control.thLow;
    thHigh = cfg.control.thHigh;
    wshift = cfg.spectro.wshift;
    c1 = cfg.classes(1);   % decided when D(:,1) >= thHigh
    c2 = cfg.classes(2);   % decided when D(:,1) <= thLow

    nWin = size(pp, 1);

    isTrialStart = false(nWin, 1);
    isTrialStart([trials.cfStart]) = true;

    D = 0.5 * ones(nWin, 2);
    for w = 2:nWin
        if isTrialStart(w)
            D(w, :) = [0.5 0.5];
        else
            D(w, :) = alpha * D(w-1, :) + (1 - alpha) * pp(w, :);
        end
    end

    nTrials = numel(trials);
    predForced  = zeros(nTrials, 1);
    predDecided = nan(nTrials, 1);
    timeCmd     = nan(nTrials, 1);

    for t = 1:nTrials
        seg = D(trials(t).cfStart:trials(t).cfStop, 1);
        iHigh = find(seg >= thHigh, 1, 'first');
        iLow  = find(seg <= thLow,  1, 'first');

        if isempty(iHigh) && isempty(iLow)
            predForced(t) = (seg(end) >= 0.5) * c1 + (seg(end) < 0.5) * c2;
        else
            if isempty(iLow) || (~isempty(iHigh) && iHigh <= iLow)
                decision = c1;  crossIdx = iHigh;
            else
                decision = c2;  crossIdx = iLow;
            end
            predDecided(t) = decision;
            predForced(t)  = decision;
            timeCmd(t)     = (crossIdx - 1) * wshift;
        end
    end
end
