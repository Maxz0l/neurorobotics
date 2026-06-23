# MATLAB Utils Reference

Neurorobotics 2025/2026

Last updated: after Lab04 - MI BMI logarithmic band power

## Purpose of this folder

The `matlab/utils/` folder contains reusable MATLAB functions used across the EEG/BCI labs.

The goal is to avoid duplicating the same code in every lab script. Lab scripts should describe the scientific workflow, while reusable technical operations should be implemented here.

This document must be updated progressively after each lab so that, before starting Assignment 1, the full processing pipeline is clear and reusable.

---

# Current utility functions

## 1. `load_gdf_file.m`

### Purpose

Loads one `.gdf` file using BioSig and separates the EEG channels from the trigger channel.

### Function call

```matlab
[sEEG, sTrigger, h] = load_gdf_file(filename);
```

### Inputs

| Input | Description |
|---|---|
| `filename` | Full path to one `.gdf` file |

### Outputs

| Output | Description |
|---|---|
| `sEEG` | EEG data matrix `[samples x 16 channels]` |
| `sTrigger` | Trigger channel `[samples x 1]` |
| `h` | Header structure returned by `sload()` |

### Internal dependencies

| Dependency | Role |
|---|---|
| `sload()` | BioSig function used to load the GDF file |

### Depends on other utils?

No.

### Used by

| File / function | Role |
|---|---|
| `concat_gdf_runs.m` | Loads each GDF file before concatenation |

### Notes

The GDF files contain 17 columns:

- channels `1:16` = EEG channels
- channel `17` = trigger channel

The trigger channel is separated immediately to prevent it from being accidentally used in EEG filtering, spatial filtering, bandpower computation, or classification.

---

## 2. `concat_gdf_runs.m`

### Purpose

Loads and concatenates several GDF runs into one continuous EEG matrix, one trigger vector, and one corrected event structure.

### Function call

```matlab
[S_eeg_all, S_trigger_all, EVENT_all, Rk, headers, sampleRate] = ...
    concat_gdf_runs(files, rawDataDir);
```

### Inputs

| Input | Description |
|---|---|
| `files` | Cell array containing GDF filenames |
| `rawDataDir` | Folder containing the GDF files |

### Outputs

| Output | Description |
|---|---|
| `S_eeg_all` | Concatenated EEG data `[total_samples x 16 channels]` |
| `S_trigger_all` | Concatenated trigger vector `[total_samples x 1]` |
| `EVENT_all` | Concatenated event structure with corrected positions |
| `Rk` | Run index vector `[total_samples x 1]` |
| `headers` | Cell array containing the header of each GDF file |
| `sampleRate` | Sampling rate in Hz |

### Internal dependencies

| Dependency | Role |
|---|---|
| `load_gdf_file.m` | Loads each individual GDF file and separates EEG/trigger |

### Depends on other utils?

Yes.

```text
concat_gdf_runs.m
└── load_gdf_file.m
```

### Used by

| File / function | Role |
|---|---|
| `lab03_gdf_concatenation.m` | Loads and concatenates the three offline runs |
| `lab04_log_bandpower.m` | Loads and concatenates the offline runs before bandpower computation |

### Important details

Each GDF file has its own local event positions. Therefore, when several files are concatenated, event positions from the second file onward must be shifted.

Example:

```matlab
EVENT_all.POS = [EVENT_all.POS; h.EVENT.POS(:) + sampleOffset];
```

The sample offset is updated after each run:

```matlab
sampleOffset = sampleOffset + size(sEEG, 1);
```

Without this correction, event labels would be temporally wrong after the first run.

### Future use

This function will be reused in:

- Lab05 - Spatial filters
- Lab06 - ERD/ERS on logarithmic band power
- Lab07 - Spectrogram ERD/ERS
- Lab08 - Feature selection and classification
- Lab09 - Classification and control framework
- Assignment 1

For Assignment 1, this function may need to be generalized to handle multiple subjects, days, offline runs, and online runs.

---

## 3. `create_label_vectors.m`

### Purpose

Creates sample-wise label vectors from a GDF event structure.

### Function call

```matlab
labels = create_label_vectors(EVENT, nSamples);
```

### Inputs

| Input | Description |
|---|---|
| `EVENT` | Event structure with fields `TYP`, `POS`, `DUR` |
| `nSamples` | Total number of samples in the EEG signal |

### Outputs

The function returns a structure:

```matlab
labels.Tk
labels.Fk
labels.Ak
labels.AkPlot
labels.CFk
labels.Xk
```

| Label vector | Description |
|---|---|
| `Tk` | Trial index vector |
| `Fk` | Fixation vector, original event code `786` |
| `Ak` | Cue vector, original event codes `771` and `773` |
| `AkPlot` | Cue vector for visualization only: `1 = feet`, `2 = hands` |
| `CFk` | Continuous feedback vector, original event code `781` |
| `Xk` | Hit/miss vector, original event codes `897` and `898` |

### Internal dependencies

None.

### Depends on other utils?

No.

### Used by

| File / function | Role |
|---|---|
| `lab03_gdf_concatenation.m` | Creates label vectors after concatenating GDF files |
| `lab04_log_bandpower.m` | Keeps the same event-labeling logic as previous labs |

### Important distinction: `Ak` vs `AkPlot`

`Ak` must keep the original GDF event codes:

- `771` = both feet
- `773` = both hands

This is important for scientific processing and later classification.

`AkPlot` is only used for visualization:

- `0` = no cue
- `1` = both feet
- `2` = both hands

This makes plots easier to read because the original values `771` and `773` are too close to distinguish clearly on a graph.

Do not replace `Ak` with `AkPlot` in processing code.

### Future use

This function will be useful for:

- selecting fixation periods,
- selecting cue periods,
- selecting continuous feedback periods,
- extracting samples for feature computation,
- preparing labels for classification,
- separating task-related EEG from irrelevant periods.

Examples:

```matlab
P = PSD(CFk == 781, :, :);
```

or:

```matlab
cueSamples = S_eeg_all(Ak ~= 0, :);
```

---

## 4. `extract_trials.m`

### Purpose

Extracts trial-based EEG segments from a continuous EEG signal using event markers.

### Function call

```matlab
[Trials, Ck, trialInfo] = extract_trials( ...
    S, EVENT, channels, sampleRate, startEvent);
```

### Inputs

| Input | Description |
|---|---|
| `S` | EEG data matrix `[samples x channels]` |
| `EVENT` | Event structure with fields `TYP`, `POS`, `DUR` |
| `channels` | Channels to extract. Use `[]` to keep all channels |
| `sampleRate` | Sampling rate in Hz |
| `startEvent` | Event used as trial start, for example `1` or `786` |

### Outputs

| Output | Description |
|---|---|
| `Trials` | Trial matrix `[samples_per_trial x channels x trials]` |
| `Ck` | Cue label for each trial `[trials x 1]` |
| `trialInfo` | Table containing trial metadata |

### `trialInfo` fields

| Field | Description |
|---|---|
| `Trial` | Trial index |
| `StartSample` | Trial start sample |
| `FixationSample` | Fixation event sample |
| `CueSample` | Cue event sample |
| `FeedbackSample` | Continuous feedback event sample |
| `EndSample` | Trial end sample |
| `LengthSamples` | Original trial length |
| `Cue` | Trial class: `771` or `773` |

### Internal dependencies

None.

### Depends on other utils?

No.

### Used by

| File / function | Role |
|---|---|
| `lab03_gdf_concatenation.m` | Extracts trials after concatenation and label creation |
| `lab04_log_bandpower.m` | Extracts raw, filtered, and log-bandpower trials |

### Important behavior

The function stores trials in a 3D matrix:

```text
[samples x channels x trials]
```

For this to work, all trials must have the same number of samples. If the original trials have slightly different lengths, the function truncates all trials to the shortest trial length.

This is acceptable for Lab03 and Lab04, but later analyses may require fixed time windows relative to specific events.

### Start event choice

For Lab04, trials are extracted from the fixation event:

```matlab
trialStartEvent = 786;
```

This is consistent with the Lab04 instruction that a trial can be assumed to last from fixation cross to the end of continuous feedback.

---

## 5. `compute_log_bandpower.m`

### Purpose

Computes logarithmic band power from continuous EEG data.

This function implements the main feature extraction step introduced in Lab04. It transforms raw EEG signals into log-bandpower features by applying a frequency-domain filter, estimating signal power, smoothing the power over time, and applying a logarithmic transform.

This utility is designed to be reused in later labs and in Assignment 1.

### Function call

```matlab
[logPower, filteredData, cfg] = compute_log_bandpower(data, sampleRate, freqBand);
```

With optional parameters:

```matlab
[logPower, filteredData, cfg] = compute_log_bandpower( ...
    data, sampleRate, freqBand, ...
    'FilterOrder', 4, ...
    'MovingWindowSec', 1);
```

### Inputs

| Input | Description |
|---|---|
| `data` | EEG data matrix `[samples x channels]` |
| `sampleRate` | Sampling rate in Hz |
| `freqBand` | Frequency band `[low high]` in Hz |

### Optional parameters

| Parameter | Default | Description |
|---|---:|---|
| `FilterOrder` | `4` | Butterworth filter order |
| `MovingWindowSec` | `1` | Moving average window length in seconds |
| `Epsilon` | `eps` | Small value added before the logarithm to avoid `log(0)` |

### Outputs

| Output | Description |
|---|---|
| `logPower` | Logarithmic band power `[samples x channels]` |
| `filteredData` | Bandpass-filtered EEG data `[samples x channels]` |
| `cfg` | Configuration structure containing filter parameters and coefficients |

### Processing pipeline

The function applies the following steps:

1. Butterworth bandpass filtering.
2. Zero-phase filtering using `filtfilt`.
3. Squaring of the filtered signal.
4. Moving average over a 1-second window.
5. Logarithmic transform.

```matlab
filteredData = filtfilt(b, a, double(data));
squaredData = filteredData .^ 2;
powerData   = movmean(squaredData, movingWindowSamples, 1);
logPower    = log(powerData + epsilonValue);
```

### Example

```matlab
muBand = [8 12];
betaBand = [18 30];

[logPowerMu, filteredMu, cfgMu] = compute_log_bandpower( ...
    S_eeg_all, sampleRate, muBand, ...
    'FilterOrder', 4, ...
    'MovingWindowSec', 1);

[logPowerBeta, filteredBeta, cfgBeta] = compute_log_bandpower( ...
    S_eeg_all, sampleRate, betaBand, ...
    'FilterOrder', 4, ...
    'MovingWindowSec', 1);
```

### Internal dependencies

| Dependency | Role |
|---|---|
| `butter()` | Designs the Butterworth bandpass filter |
| `filtfilt()` | Applies zero-phase filtering |
| `movmean()` | Computes the moving average power estimate |

### Depends on other utils?

No.

### Used by

| File / function | Role |
|---|---|
| `lab04_log_bandpower.m` | Computes log-bandpower in mu and beta bands |

### Important notes

The input data must contain only EEG channels. The trigger channel must not be included.

For the current dataset, the EEG signal has 16 channels and the trigger channel is separated by `load_gdf_file.m`.

The logarithmic transform uses MATLAB's natural logarithm `log()`. This is acceptable as long as the same convention is used consistently across the analysis pipeline.

### Future use

This function will be reused in:

- Lab05 - Spatial filters on logarithmic band power
- Lab06 - ERD/ERS on logarithmic band power
- Lab08 - Feature selection and classification
- Lab09 - Classification and control framework
- Assignment 1
- Assignment 2 conceptual implementation of bandpower thresholding

---

# Git rules for this folder

The following files can be versioned:

```text
*.m
*.md
*.txt
```

The following files must not be committed:

```text
*.gdf
*.mat
*.set
*.fdt
```

Heavy EEG data files must stay outside Git tracking.
