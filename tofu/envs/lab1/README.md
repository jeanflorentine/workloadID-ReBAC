# Lab1 Environment

This environment wires together the portable-first Orange Lab 1 scaffold.

## Purpose

1. Keep target selection explicit.
2. Keep host-specific values outside reusable modules.
3. Keep the first apply path small and reviewable.

## Expected workflow

1. Copy `backend.hcl.example` to a local `backend.hcl` when a backend is selected.
2. Copy `terraform.tfvars.example` to a local `terraform.tfvars` and fill target values.
3. Start with one infrastructure wrapper only.
4. Add service modules incrementally after the runtime path is validated.
