function fisher = compute_fisher_score(F, labels)
%COMPUTE_FISHER_SCORE Fisher score of each feature for a two-class problem.
%
% Neurorobotics 2025/2026
%
% For each column (feature) of F, computes the Fisher score between the two
% classes present in `labels`:
%
%     fisher = (mu1 - mu2)^2 / (var1 + var2)
%
% A higher score means the feature separates the two classes better
% (class means far apart relative to the within-class spread).
%
% Inputs:
%   F        [observations x features] feature matrix
%   labels   [observations x 1] class label for each observation
%            (exactly two distinct values must be present)
%
% Outputs:
%   fisher   [1 x features] Fisher score per feature

    classValues = unique(labels);

    if numel(classValues) ~= 2
        error('compute_fisher_score:TwoClassesRequired', ...
            'Exactly two classes are required, found %d.', numel(classValues));
    end

    idx1 = labels == classValues(1);
    idx2 = labels == classValues(2);

    mu1 = mean(F(idx1, :), 1);
    mu2 = mean(F(idx2, :), 1);
    v1  = var(F(idx1, :), 0, 1);
    v2  = var(F(idx2, :), 0, 1);

    fisher = (mu1 - mu2).^2 ./ (v1 + v2);
end
