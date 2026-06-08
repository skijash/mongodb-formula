# Per-platform pillar for RHEL 8 kitchen targets (rockylinux-8,
# almalinux-8, oraclelinux-8). On those saltimages, salt-3006-LTS
# pulls in python3.11 transitively but no `python3` alternative is
# wired up, so point venv creation at python3.11 explicitly. Composed
# via `include: [default]` so the rest of the shared kitchen pillar
# still applies.
include:
  - default

mongodb:
  pkg:
    venv_python: python3.11
