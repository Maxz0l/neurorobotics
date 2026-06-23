# MATLAB Utils Reference

Neurorobotics 2025/2026

Last updated: after Lab06 - ERD/ERS on band power

## Purpose of this folder

The `matlab/utils/` folder contains reusable MATLAB functions used across the EEG/BCI labs.

The goal is to avoid duplicating technical operations in every lab script. Lab scripts should describe the scientific workflow, while reusable operations should be implemented as functions.

This folder is progressively updated to build a clean and reusable processing pipeline for Assignment 1.

## Current utility functions

```text
matlab/utils/
├── load_gdf_file.m
├── concat_gdf_runs.m
├── create_label_vectors.m
├── extract_trials.m
├── compute_bandpower.m        # general band power, optional log
├── compute_log_bandpower.m    # backward-compatible wrapper (ApplyLog = true)
├── apply_car_filter.m
└── apply_laplacian_filter.m
```

---

# 1. load_gdf_file.m

## Purpose

Loads one `.gdf` file using BioSig and separates EEG channels from the trigger channel.

## Function call

```matlab
[sEEG, sTrigger, h] = load_gdf_file(filename);
```

## Inputs

| Input | Description |
|---|---|
| `filename` | Full path to one `.gdf` file |

## Outputs

| Output | Description |
|---|---|
| `sEEG` | EEG data matrix `[samples x 16 channels]` |
| `sTrigger` | Trigger channel `[samples x 1]` |
| `h` | Header structure returned by `sload()` |

## Important notes

The GDF files contain 17 columns:

```text
channels 1:16 = EEG channels
channel 17    = trigger channel
```

The trigger channel is separated immediately to prevent it from being used accidentally in EEG filtering, spatial filtering, bandpower computation, or classification.

---

# 2. concat_gdf_runs.m

## Purpose

Loads and concatenates several GDF runs into one continuous EEG matrix, one trigger vector, and one corrected event structure.

## Function call

```matlab
[S_eeg_all, S_trigger_all, EVENT_all, Rk, headers, sampleRate] = ...
    concat_gdf_runs(files, rawDataDir);
```

## Inputs

| Input | Description |
|---|---|
| `files` | Cell array containing GDF filenames |
| `rawDataDir` | Folder containing the GDF files |

## Outputs

| Output | Description |
|---|---|
| `S_eeg_all` | Concatenated EEG data `[total_samples x 16 channels]` |
| `S_trigger_all` | Concatenated trigger vector `[total_samples x 1]` |
| `EVENT_all` | Concatenated event structure with corrected positions |
| `Rk` | Run index vector `[total_samples x 1]` |
| `headers` | Cell array containing the header of each GDF file |
| `sampleRate` | Sampling rate in Hz |

## Important notes

Each GDF file has local event positions. Therefore, when files are concatenated, event positions from the second file onward must be shifted by the cumulative number of samples already loaded.

Without this correction, events after the first run would be temporally wrong.

---

# 3. create_label_vectors.m

## Purpose

Creates sample-wise label vectors from a GDF event structure.

## Function call

```matlab
labels = create_label_vectors(EVENT, nSamples);
```

## Inputs

| Input | Description |
|---|---|
| `EVENT` | Event structure with fields `TYP`, `POS`, `DUR` |
| `nSamples` | Total number of EEG samples |

## Outputs

The function returns a structure containing label vectors such as:

| Field | Description |
|---|---|
| `Tk` | Trial index vector |
| `Fk` | Fixation vector, event code 786 |
| `Ak` | Cue vector, original event codes 771 and 773 |
| `AkPlot` | Cue vector for visualization only |
| `CFk` | Continuous feedback vector, event code 781 |
| `Xk` | Hit/miss vector, event codes 897 and 898 |

## Important distinction

`Ak` must keep the original GDF event codes:

```text
771 = both feet
773 = both hands
```

`AkPlot` is only for visualization.

Do not use `AkPlot` for scientific processing or classification.

---

# 4. extract_trials.m

## Purpose

Extracts trial-based EEG or feature segments from continuous data using event markers.

## Function call

```matlab
[Trials, Ck, trialInfo] = extract_trials(S, EVENT, channels, sampleRate, startEvent);
```

## Inputs

| Input | Description |
|---|---|
| `S` | Continuous data matrix `[samples x channels]` |
| `EVENT` | Event structure with fields `TYP`, `POS`, `DUR` |
| `channels` | Channels to extract. Use `[]` to keep all channels |
| `sampleRate` | Sampling rate in Hz |
| `startEvent` | Event used as trial start, for example 1 or 786 |

## Outputs

| Output | Description |
|---|---|
| `Trials` | Trial matrix `[samples_per_trial x channels x trials]` |
| `Ck` | Cue label for each trial `[trials x 1]` |
| `trialInfo` | Table containing trial metadata |

## Important notes

The function truncates trials to the shortest trial length so they can be stored in a 3D matrix.

This is acceptable for the current labs, but later analyses may require stricter control of trial windows relative to specific events.

---

# 5. compute_bandpower.m

## Purpose

Computes band power for a selected frequency band. By default the result is log-transformed, but the log step can be disabled through the `ApplyLog` option.

The log is disabled for ERD/ERS (Lab06): there the data is normalized by the reference period instead, so a logarithmic transform must not be applied beforehand.

## Function call

```matlab
[bandPower, filteredData, cfg] = compute_bandpower(S, sampleRate, frequencyBand);
[bandPower, filteredData, cfg] = compute_bandpower(S, sampleRate, frequencyBand, 'ApplyLog', false);
```

## Inputs

| Input | Description |
|---|---|
| `S` | EEG data `[samples x channels]` |
| `sampleRate` | Sampling rate in Hz |
| `frequencyBand` | Frequency band `[low high]`, for example `[8 12]` |

## Optional name-value arguments

| Name | Default | Description |
|---|---|---|
| `FilterOrder` | `4` | Butterworth filter order |
| `MovingWindowSec` | `1` | Moving-average window in seconds |
| `Epsilon` | `eps` | Constant added before the log to avoid `log(0)` |
| `ApplyLog` | `true` | Apply the logarithmic transform |

## Outputs

| Output | Description |
|---|---|
| `bandPower` | Band power, log-transformed if `ApplyLog = true` `[samples x channels]` |
| `filteredData` | Band-pass filtered EEG signal `[samples x channels]` |
| `cfg` | Configuration structure (parameters and filter coefficients) |

## Processing pipeline

```text
band-pass Butterworth filtering
-> zero-phase filtering with filtfilt
-> signal rectification by squaring
-> moving average with a 1-second window
-> optional logarithmic transform (ApplyLog)
```

## Used by

```text
Lab04 - MI BMI logarithmic band power      (ApplyLog = true)
Lab05 - Spatial filters on log band power  (ApplyLog = true)
Lab06 - ERD/ERS on band power              (ApplyLog = false)
```

## Future use

```text
Lab07 - ERD/ERS on spectrogram
Assignment 1
```

---

# 5b. compute_log_bandpower.m

## Purpose

Backward-compatible wrapper kept so that the Lab04 and Lab05 scripts keep working without modification. It simply calls `compute_bandpower()` with `ApplyLog = true`.

## Function call

```matlab
[logPower, filteredSignal] = compute_log_bandpower(S, sampleRate, frequencyBand);
```

This is equivalent to:

```matlab
[logPower, filteredSignal] = compute_bandpower(S, sampleRate, frequencyBand, 'ApplyLog', true);
```

## Used by

```text
Lab04 - MI BMI logarithmic band power
Lab05 - Spatial filters on logarithmic band power
```

---

# 6. apply_car_filter.m

## Purpose

Applies the Common Average Reference spatial filter.

## Function call

```matlab
S_car = apply_car_filter(S);
```

## Inputs

| Input | Description |
|---|---|
| `S` | EEG data `[samples x channels]` |

## Outputs

| Output | Description |
|---|---|
| `S_car` | CAR-filtered EEG data `[samples x channels]` |

## Principle

At each time sample, the average across all EEG channels is removed:

```matlab
S_car = S - mean(S, 2);
```

This reduces activity common to all channels.

## Used by

```text
Lab05 - Spatial filters on logarithmic band power
```

## Future use

The CAR filter may be reused for preprocessing comparisons in Assignment 1.

---

# 7. apply_laplacian_filter.m

## Purpose

Applies the Laplacian spatial filter using the 16-channel Laplacian mask provided on Moodle.

## Function call

```matlab
S_lap = apply_laplacian_filter(S, lapFile);
```

## Inputs

| Input | Description |
|---|---|
| `S` | EEG data `[samples x channels]` |
| `lapFile` | Path to `laplacian16.mat` |

## Outputs

| Output | Description |
|---|---|
| `S_lap` | Laplacian-filtered EEG data `[samples x channels]` |

## Expected `.mat` content

The file must contain a Laplacian matrix:

```text
lap [16 x 16]
```

The filtering operation is:

```matlab
S_lap = S * lap;
```

## Important notes

The input data must contain only the 16 EEG channels.

The trigger channel must not be included. If the input has 17 columns, the multiplication with the Laplacian matrix is wrong and should be fixed before filtering.

## Used by

```text
Lab05 - Spatial filters on logarithmic band power
Lab06 - ERD/ERS on band power
```

## Future use

The Laplacian filter is likely to be useful in:

```text
Lab07 - ERD/ERS on spectrogram
Lab08 - Feature selection and classification
Lab09 - Classification and control framework
Assignment 1
```

---

# Current pipeline after Lab06

The reusable pipeline is now:

```text
load GDF file
-> separate EEG and trigger channel
-> concatenate offline runs
-> correct event positions
-> optionally apply spatial filter
   -> none
   -> CAR
   -> Laplacian
-> compute band power
   -> log for features (Lab04, Lab05)
   -> no log for ERD/ERS (Lab06)
-> extract trials and the fixation reference period
-> average or compare motor imagery classes
-> compute ERD/ERS relative to the fixation reference (Lab06)
```

## Git notes

Do not version heavy binary files:

```text
*.gdf
*.mat
*.set
*.fdt
```

Version only source and documentation files:

```text
*.m
README.md
light figures
```

## Next steps

The next labs will build on this structure:

```text
Lab07 - ERD/ERS on spectrogram
Lab08 - Feature selection and classification
Lab09 - Classification and control framework
```

For Assignment 1, these utilities should be generalized to handle multiple subjects, days, offline runs, and online runs.
