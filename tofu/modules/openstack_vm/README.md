# openstack_vm

Thin wrapper for the reference lab VM on OpenStack.

## Scope

1. Hold OpenStack-specific compute, image, and network settings.
2. Reuse the same reference VM shape as the other targets.
3. Keep all in-cluster workload logic outside this module.
