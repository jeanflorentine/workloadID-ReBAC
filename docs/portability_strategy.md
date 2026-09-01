# Portability Strategy

## Core requirement

The lab must keep working when home infrastructure is unavailable.

## Target split

### Target 1: Home Proxmox

Use: bootstrap before the Orange laptop arrives.

Advantages:
1. Available immediately.
2. Familiar platform.
3. Good place to start the first k3s runtime.

Limit:
1. Must never become a required dependency after Friday.

### Target 2: Orange laptop

Use: primary autonomous execution target after delivery.

Advantages:
1. Works from office, customer site, or travel.
2. No dependency on home connectivity.
3. Best fit for day-to-day continuity.

Constraints:
1. Corporate policy may restrict local hypervisor choice.
2. CPU and RAM may limit optional heavy components.

### Target 3: Orange Proxmox or OpenStack

Use: secondary enterprise-hosted target when available.

Advantages:
1. Better for demonstrations, durability, and team sharing.
2. Better for scale-up or optional multi-node experiments.

Constraint:
1. Availability depends on Orange internal access and approval.

## Decision rule

1. Build the VM and cluster definitions once.
2. Keep target-specific wrappers thin.
3. Prefer rebuildability over hand-crafted migration.
4. Test the Orange laptop path as the primary acceptance criterion.
