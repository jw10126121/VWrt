# VIKINGYFY Device Branch Selection

## Goal

Make VIKINGYFY source selection choose the correct upstream branch by device family:

- IPQ devices use `main`
- non-IPQ devices use `owrt`

This avoids pulling the Qualcomm-focused `main` branch for MediaTek targets such as `GL-MT6000-WIFI`.

## Scope

Change only source-selection behavior:

- keep `lean -> master`
- keep `generic -> main`
- for `VIKINGYFY`, branch selection depends on `WRT_DEVICE`

No device config, package selection, or build-script behavior changes are included.

## Design

### Branch rule

`resolve_source_default_branch(source_flavor, device_name)` applies these rules:

- `VIKINGYFY` and `device_name` matches `IPQ*` -> `main`
- `VIKINGYFY` and all other devices -> `owrt`
- `generic` -> `main`
- everything else -> `master`

### Propagation

`resolve_source_selection()` accepts `device_name` and passes it into the default-branch resolver.

`CORE-ALL.yml` passes `WRT_DEVICE` into both source-selection call sites so environment metadata and actual clone behavior stay aligned.

## Verification

Regression coverage must prove:

- `VIKINGYFY + IPQ60XX-NOWIFI -> main`
- `VIKINGYFY + GL-MT6000-WIFI -> owrt`
- `lean + IPQ60XX-NOWIFI -> master`
