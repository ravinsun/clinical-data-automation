# Clinical Data Automation — CDISC SDTM/ADaM Pipeline

> SAS macro libraries for end-to-end clinical data submission automation,
> built for GxP-regulated pharma environments targeting FDA/EMA submissions.

## What this repo contains

| Folder | What it does |
|---|---|
| `sdtm-pipeline/` | XPT-to-dataset-JSON conversion — replaces legacy XPT format for FDA submissions |
| `define-xml/` | define.xml v2.0 generator — reads SDTM specs and produces CDISC-compliant metadata |
| `xpt-to-json/` | JSON validation and comparison tools (SAS + R) |
| `adam-pipeline/` | ADaM dataset automation macros |
| `ecrf-acrf/` | eCRF to aCRF annotation automation |

## Key features

- Converts SDTM XPT datasets to **CDISC dataset-JSON v1.0** format
- Generates **define.xml v2.0** from specs Excel — fully Pinnacle 21 validated
- Automates **eCRF/aCRF** annotation workflows for FDA submission packages
- Eliminates XPT format dependency — validated JSON pipeline accepted by Pinnacle 21
- Built entirely in **SAS macros** for regulated GxP environments

## Tech stack

SAS 9.4 · SAS Viya · Python · R · CDISC SDTM IG 3.3 · define.xml v2.0 · Pinnacle 21

## Standards

CDISC · SDTM · ADaM · define.xml v2.0 · dataset-JSON v1.0 · 21 CFR Part 11 · ICH E6

## Note on data

All macro libraries use synthetic/sample data.
No real patient data, study IDs, or proprietary metadata are included in this repository.
