# Neurorobotics 2025/2026

Course work for the Neurorobotics course (University of Padova): the MATLAB
EEG/BCI labs and the two assignments.

## Repository structure

```text
Neurorobotics/
├── matlab/
│   ├── labs/        one folder per lab (lab02 ... lab09): script + README + figures
│   ├── utils/       reusable functions (the toolbox) + MATLAB_Utils_Reference.md
│   ├── data/        raw / external / processed EEG data (not versioned)
│   ├── toolboxes/   EEGLAB, BioSig (not versioned)
│   └── startup_neurorobotics.m   adds the project paths (run once per session)
├── assignments/
│   ├── assignment1/  MATLAB MI-BCI decoding (scripts, figures, report)
│   └── assignment2/  ROS-Neuro processing chain (config, launch, src)
├── Neurorobotics Cours/   course PDFs: lectures and lab/assignment statements (not versioned)
└── docs/
```

## Where to find things

| You want | Go to |
|---|---|
| The lab scripts | `matlab/labs/<labXX>/` (each lab has its own README) |
| The reusable functions | `matlab/utils/` (documented in `MATLAB_Utils_Reference.md`) |
| Assignment 1 (MATLAB, MI-BCI) | `assignments/assignment1/` (see its README) |
| Assignment 2 (ROS-Neuro) | `assignments/assignment2/` |

## Getting started (MATLAB)

1. Open MATLAB in the `matlab/` folder.
2. Run `startup_neurorobotics.m` once (adds `utils`, `labs`, EEGLAB and BioSig to the path).
3. Open a lab or assignment script and run it.

## Notes

- EEG data and external toolboxes are **not** versioned (see `.gitignore`).
- Author: LORANDI Enzo.
