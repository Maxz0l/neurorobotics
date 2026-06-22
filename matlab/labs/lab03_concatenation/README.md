# Lab03 - GDF Data Concatenation

Neurorobotics 2025/2026  
MATLAB / EEG / BCI

## Objective

The objective of this lab is to concatenate several offline GDF runs into one continuous EEG dataset, correct the event positions after concatenation, create sample-wise label vectors, extract motor imagery trials, and visualize both single trials and grand averages.

This lab is mainly a data-structuring step. It does not yet perform advanced EEG processing such as bandpower computation, spatial filtering, ERD/ERS, or classification.

## Lab requirements

The Lab03 instructions require the following steps:

- Load the offline GDF files.
- Concatenate the EEG data.
- Concatenate the event information: `POS`, `TYP`, and `DUR`.
- Correct event positions from the second GDF file onward.
- Create label vectors: `Tk`, `Fk`, `Ak`, `CFk`, `Xk`, and `Rk`.
- Extract trials into a matrix `[samples x channels x trials]`.
- Create `Ck`, the cue label vector for each trial.
- Plot one trial per cue and compute grand averages per cue.

## Files used

The lab uses the three offline GDF files stored in:

```text
matlab/data/raw/
```

Files:

```text
ah7.20170613.161402.offline.mi.mi_bhbf.gdf
ah7.20170613.162331.offline.mi.mi_bhbf.gdf
ah7.20170613.162934.offline.mi.mi_bhbf.gdf
```

These files are raw EEG recordings and must not be committed to Git.

## Script

Main script:

```text
matlab/labs/lab03_concatenation/lab03_gdf_concatenation.m
```

The script performs the complete Lab03 workflow:

1. Configure paths and file names.
2. Load and concatenate the GDF runs using `concat_gdf_runs.m`.
3. Check consistency of the concatenated data.
4. Create label vectors using `create_label_vectors.m`.
5. Visualize the label vectors and run index vector.
6. Extract trials using `extract_trials.m`.
7. Plot one selected trial for each motor imagery cue.
8. Compute and plot grand averages for each cue.

## Utility functions used

The script relies on reusable functions from:

```text
matlab/utils/
```

### `load_gdf_file.m`

Loads one GDF file using BioSig `sload()` and separates:

```text
channels 1:16 = EEG channels
channel 17    = trigger channel
```

This prevents the trigger channel from being accidentally used as an EEG channel in later processing steps.

### `concat_gdf_runs.m`

Loads and concatenates several GDF runs. It returns:

```matlab
[S_eeg_all, S_trigger_all, EVENT_all, Rk, headers, sampleRate]
```

Important detail: event positions are corrected using a cumulative `sampleOffset`, so that events from the second and third files are aligned with the concatenated signal.

### `create_label_vectors.m`

Creates sample-wise label vectors from the concatenated event structure:

```text
Tk     = trial index vector
Fk     = fixation period vector
Ak     = cue vector with original event codes 771 / 773
AkPlot = cue vector for visualization only: 1 = feet, 2 = hands
CFk    = continuous feedback vector
Xk     = hit/miss vector
```

`Ak` keeps the original GDF event codes. `AkPlot` exists only to make the cue plot readable.

### `extract_trials.m`

Extracts trials from the continuous EEG signal and stores them in a 3D matrix:

```text
[samples x channels x trials]
```

For Lab03, trials are extracted from event `1`, corresponding to the full trial start. Trials with slightly different lengths are truncated to the shortest common length so they can be stored in one 3D matrix.

## Event codes

Relevant event codes used in this lab:

| Code | Meaning |
|---:|---|
| `1` | Trial start |
| `786` | Fixation cross |
| `771` | Both feet |
| `773` | Both hands |
| `781` | Continuous feedback |
| `897` | Target hit |
| `898` | Target miss |

Only `771` and `773` are expected as cue labels in the offline files used here.

## Output data structures

After running the script, the main variables are:

| Variable | Description |
|---|---|
| `S_eeg_all` | Concatenated EEG data `[samples x 16]` |
| `S_trigger_all` | Concatenated trigger channel `[samples x 1]` |
| `EVENT_all` | Concatenated event structure with corrected positions |
| `Rk` | Run index vector |
| `labels` | Structure containing `Tk`, `Fk`, `Ak`, `AkPlot`, `CFk`, `Xk` |
| `Trials` | Extracted trials `[samples x channels x trials]` |
| `Ck` | Cue label for each trial |
| `trialInfo` | Table containing trial metadata |

Expected final trial distribution:

```text
Cue 771 - Both feet : 45 trials
Cue 773 - Both hands: 45 trials
```

## Figures

The generated figures are stored in the local `images/` folder of the lab.

### Label vectors

![Label vectors](images/Lab03%20-%20Label%20vectors%20on%20concatenated%20data.png)

This figure shows the sample-wise label vectors:

- `Tk`: trial index vector.
- `Fk`: fixation periods.
- `Ak`: cue periods, displayed with `AkPlot` for readability.
- `CFk`: continuous feedback periods.
- `Xk`: hit/miss periods.

The original cue vector `Ak` still keeps the real GDF event codes `771` and `773`. The displayed version uses `1` for both feet and `2` for both hands.

### Run index vector

![Run index vector](images/Lab03%20-%20Run%20index%20vector.png)

This figure verifies that the concatenated signal is composed of three consecutive runs.

`Rk = 1` corresponds to the first GDF file, `Rk = 2` to the second file, and `Rk = 3` to the third file.

### Single trials by cue

![Single trials by cue](images/Lab03%20-%20Single%20trials%20by%20cue.png)

This figure displays one selected EEG channel for:

- the first available `both feet` trial,
- the first available `both hands` trial.

The signal is raw EEG, so it is expected to be noisy. This plot is mainly a sanity check for trial extraction, not a discriminative analysis.

### Grand averages by cue

![Grand averages by cue](images/Lab03%20-%20Grand%20averages%20by%20cue.png)

This figure displays the average raw EEG signal across all trials of each class for the selected channel.

The averaging is performed over the third dimension of `Trials`, which corresponds to the trial dimension:

```matlab
avgFeet  = mean(Trials(:, :, Ck == BOTH_FEET), 3);
avgHands = mean(Trials(:, :, Ck == BOTH_HANDS), 3);
```

This reduces trial-specific noise, but raw EEG averages are not expected to clearly separate motor imagery classes. Discriminative information is expected later in spectral power features, especially in the mu and beta bands.

## Interpretation

This lab validates the basic EEG data pipeline:

```text
GDF files
   ↓
load_gdf_file()
   ↓
concat_gdf_runs()
   ↓
create_label_vectors()
   ↓
extract_trials()
   ↓
single-trial and grand-average visualization
```

The important result is not a strong visual separation between both feet and both hands in raw EEG. The important result is that the data, events, labels, and trials are correctly aligned and ready for later processing.

## Link with Assignment 1

Lab03 prepares the foundation for Assignment 1.

Assignment 1 will require analyzing multiple subjects, days, offline runs, and online runs. The same core ideas will be reused:

- load GDF data,
- keep EEG and trigger separate,
- concatenate runs when needed,
- preserve and correct event positions,
- create reliable label vectors,
- extract task-specific trials or windows.

The current utility functions will therefore be reused and progressively generalized.

## Files created or modified

```text
matlab/labs/lab03_concatenation/lab03_gdf_concatenation.m
matlab/labs/lab03_concatenation/README.md
matlab/labs/lab03_concatenation/images/
matlab/utils/load_gdf_file.m
matlab/utils/concat_gdf_runs.m
matlab/utils/create_label_vectors.m
matlab/utils/extract_trials.m
matlab/utils/README.md
```

## Status

Lab03 is functionally complete. The current pipeline can load the offline GDF files, concatenate EEG and event data, create label vectors, extract trials, and produce the required sanity-check visualizations.

Ready for the next lab: Lab04 will build on this structure to compute logarithmic bandpower in the motor imagery frequency bands.
