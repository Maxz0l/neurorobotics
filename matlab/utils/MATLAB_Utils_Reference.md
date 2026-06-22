# MATLAB Utils Reference

Neurorobotics 2025/2026  
Last updated: after Lab03 - GDF data concatenation

## Purpose of this folder

The `matlab/utils/` folder contains reusable MATLAB functions used across the EEG/BCI labs.

The goal is to avoid duplicating the same code in every lab script. Lab scripts should describe the scientific workflow, while reusable technical operations should be implemented here.

This document must be updated progressively after each lab so that, before starting Assignment 1, the full processing pipeline is clear and reusable.

---

## Current utility functions

### 1. `load_gdf_file.m`

#### Purpose

Loads one `.gdf` file using BioSig and separates the EEG channels from the trigger channel.

#### Function call

```matlab
[sEEG, sTrigger, h] = load_gdf_file(filename);
```

#### Inputs

| Input | Description |
|---|---|
| `filename` | Full path to one `.gdf` file |

#### Outputs

| Output | Description |
|---|---|
| `sEEG` | EEG data matrix `[samples x 16 channels]` |
| `sTrigger` | Trigger channel `[samples x 1]` |
| `h` | Header structure returned by `sload()` |

#### Internal dependencies

| Dependency | Role |
|---|---|
| `sload()` | BioSig function used to load the GDF file |

#### Depends on other utils?

No.

#### Used by

| File / function | Role |
|---|---|
| `concat_gdf_runs.m` | Loads each GDF file before concatenation |

#### Notes

The GDF files contain 17 columns:

```text
channels 1:16 = EEG channels
channel 17    = trigger channel
```

The trigger channel is separated immediately to prevent it from being accidentally used in EEG filtering, spatial filtering, bandpower computation, or classification.

---

### 2. `concat_gdf_runs.m`

#### Purpose

Loads and concatenates several GDF runs into one continuous EEG matrix, one trigger vector, and one corrected event structure.

#### Function call

```matlab
[S_eeg_all, S_trigger_all, EVENT_all, Rk, headers, sampleRate] = ...
    concat_gdf_runs(files, rawDataDir);
```

#### Inputs

| Input | Description |
|---|---|
| `files` | Cell array containing GDF filenames |
| `rawDataDir` | Folder containing the GDF files |

#### Outputs

| Output | Description |
|---|---|
| `S_eeg_all` | Concatenated EEG data `[total_samples x 16 channels]` |
| `S_trigger_all` | Concatenated trigger vector `[total_samples x 1]` |
| `EVENT_all` | Concatenated event structure with corrected positions |
| `Rk` | Run index vector `[total_samples x 1]` |
| `headers` | Cell array containing the header of each GDF file |
| `sampleRate` | Sampling rate in Hz |

#### Internal dependencies

| Dependency | Role |
|---|---|
| `load_gdf_file.m` | Loads each individual GDF file and separates EEG/trigger |

#### Depends on other utils?

Yes.

```text
concat_gdf_runs.m
└── load_gdf_file.m
```

#### Used by

| File / function | Role |
|---|---|
| `lab03_gdf_concatenation.m` | Loads and concatenates the three offline runs |

#### Important details

Each GDF file has its own local event positions. Therefore, when several files are concatenated, event positions from the second file onward must be shifted.

Example:

```matlab
EVENT_all.POS = [EVENT_all.POS; h.EVENT.POS(:) + sampleOffset];
```

The `sampleOffset` is updated after each run:

```matlab
sampleOffset = sampleOffset + size(sEEG, 1);
```

Without this correction, event labels would be temporally wrong after the first run.

#### Future use

This function will be reused in:

- Lab04 - Logarithmic bandpower
- Lab05 - Spatial filters
- Lab06 - ERD/ERS on logarithmic bandpower
- Lab07 - Spectrogram ERD/ERS
- Lab08 - Feature selection and classification
- Lab09 - Classification and control framework
- Assignment 1

For Assignment 1, this function may need to be generalized to handle multiple subjects, days, offline runs, and online runs.

---

### 3. `create_label_vectors.m`

#### Purpose

Creates sample-wise label vectors from a GDF event structure.

#### Function call

```matlab
labels = create_label_vectors(EVENT, nSamples);
```

#### Inputs

| Input | Description |
|---|---|
| `EVENT` | Event structure with fields `TYP`, `POS`, `DUR` |
| `nSamples` | Total number of samples in the EEG signal |

#### Outputs

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

#### Internal dependencies

None.

#### Depends on other utils?

No.

#### Used by

| File / function | Role |
|---|---|
| `lab03_gdf_concatenation.m` | Creates label vectors after concatenating GDF files |

#### Important distinction: `Ak` vs `AkPlot`

`Ak` must keep the original GDF event codes:

```text
771 = both feet
773 = both hands
```

This is important for scientific processing and later classification.

`AkPlot` is only used for visualization:

```text
0 = no cue
1 = both feet
2 = both hands
```

This makes plots easier to read because the original values `771` and `773` are too close to distinguish clearly on a graph.

Do not replace `Ak` with `AkPlot` in processing code.

#### Future use

This function will be useful for:

- selecting fixation periods,
- selecting cue periods,
- selecting continuous feedback periods,
- extracting samples for feature computation,
- preparing labels for classification,
- separating task-related EEG from irrelevant periods.

For example, later labs may use logic such as:

```matlab
P = PSD(CFk == 781, :, :);
```

or:

```matlab
cueSamples = S_eeg_all(Ak ~= 0, :);
```

---

### 4. `extract_trials.m`

#### Purpose

Extracts trial-based EEG segments from a continuous EEG signal using event markers.

#### Function call

```matlab
[Trials, Ck, trialInfo] = extract_trials( ...
    S, EVENT, channels, sampleRate, startEvent);
```

#### Inputs

| Input | Description |
|---|---|
| `S` | EEG data matrix `[samples x channels]` |
| `EVENT` | Event structure with fields `TYP`, `POS`, `DUR` |
| `channels` | Channels to extract. Use `[]` to keep all channels |
| `sampleRate` | Sampling rate in Hz |
| `startEvent` | Event used as trial start, for example `1` or `786` |

#### Outputs

| Output | Description |
|---|---|
| `Trials` | Trial matrix `[samples_per_trial x channels x trials]` |
| `Ck` | Cue label for each trial `[trials x 1]` |
| `trialInfo` | Table containing trial metadata |

#### `trialInfo` fields

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

#### Internal dependencies

None.

#### Depends on other utils?

No.

#### Used by

| File / function | Role |
|---|---|
| `lab03_gdf_concatenation.m` | Extracts trials after concatenation and label creation |

#### Important behavior

The function stores trials in a 3D matrix:

```text
[samples x channels x trials]
```

For this to work, all trials must have the same number of samples. If the original trials have slightly different lengths, the function truncates all trials to the shortest trial length.

This is acceptable for Lab03, but later analyses may require fixed time windows relative to specific events.

#### Start event choice

For Lab03, the full trial is extracted from:

```text
event 1 = trial start
```

For later ERD/ERS analyses, it may be better to work from:

```text
event 786 = fixation
```

or to extract specific periods such as fixation and continuous feedback separately.

#### Future use

This function will be reused for:

- single-trial visualization,
- grand average visualization,
- trial-based bandpower analysis,
- ERD/ERS analysis,
- classification dataset preparation.

It may later need an improved version supporting fixed windows, for example:

```text
from cue onset to cue onset + 4 seconds
from fixation onset to feedback end
from feedback onset to feedback onset + N seconds
```

---

## Current dependency graph

```text
lab03_gdf_concatenation.m
├── concat_gdf_runs.m
│   └── load_gdf_file.m
├── create_label_vectors.m
└── extract_trials.m
```

Utility-level dependencies:

```text
concat_gdf_runs.m
└── load_gdf_file.m

create_label_vectors.m
└── no utils dependency

extract_trials.m
└── no utils dependency

load_gdf_file.m
└── BioSig sload()
```

---

## Current EEG processing pipeline

The current pipeline is:

```text
GDF files
   ↓
load_gdf_file()
   ↓
sEEG, sTrigger, h
   ↓
concat_gdf_runs()
   ↓
S_eeg_all, S_trigger_all, EVENT_all, Rk
   ↓
create_label_vectors()
   ↓
Tk, Fk, Ak, AkPlot, CFk, Xk
   ↓
extract_trials()
   ↓
Trials, Ck, trialInfo
```

This pipeline currently handles data loading, event correction, labeling, and trial extraction.

It does not yet perform advanced EEG processing such as:

- bandpass filtering,
- logarithmic bandpower,
- CAR filtering,
- Laplacian filtering,
- ERD/ERS computation,
- feature selection,
- classification.

These will be added progressively in future labs.

---

## Expected future utility functions

The following functions are expected to be added later.

### `compute_log_bandpower.m`

Expected use: Lab04 and later.

Purpose:

```text
bandpass filter → square → moving average → log transform
```

---

### `apply_car_filter.m`

Expected use: Lab05 and later.

Purpose:

```text
apply Common Average Reference spatial filtering
```

---

### `apply_laplacian_filter.m`

Expected use: Lab05, Lab06, Lab07, Lab08, Lab09.

Purpose:

```text
apply Laplacian spatial filtering using laplacian16.mat
```

---

### `compute_erd_ers.m`

Expected use: Lab06 and Lab07.

Purpose:

```text
compute ERD/ERS relative to a reference period
```

---

### `compute_fisher_score.m`

Expected use: Lab08.

Purpose:

```text
measure feature discriminability between both feet and both hands
```

---

### `train_decoder.m`

Expected use: Lab08, Lab09, Assignment 1.

Purpose:

```text
train a classification model using selected EEG features
```

---

### `evaluate_decoder.m`

Expected use: Lab08, Lab09, Assignment 1.

Purpose:

```text
evaluate predictions, class accuracy, and global accuracy
```

---

## Maintenance rules

1. Each reusable operation must be implemented in `matlab/utils/`.
2. Lab scripts should remain readable and describe the workflow.
3. Do not duplicate large code blocks between lab scripts.
4. Do not modify scientific label vectors for display purposes.
5. If a simplified vector is needed for plotting, create a separate plotting vector.
6. Keep original GDF event codes available for processing.
7. Update this README whenever a new utility function is created or modified.

---

## Current status

Completed utility functions:

```text
load_gdf_file.m
concat_gdf_runs.m
create_label_vectors.m
extract_trials.m
```

Current lab using these utilities:

```text
Lab03 - GDF data concatenation
```

Next expected utility function:

```text
compute_log_bandpower.m
```
