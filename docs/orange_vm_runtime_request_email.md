# Email Draft: Orange Laptop Runtime Decision

## Subject

Request to confirm local runtime option for the Orange integration lab: VM or WSL 2

## Message

Hello,

I am starting the new integration lab this week before receiving the Orange laptop, and I would like to align the local execution model as early as possible so I can avoid rework once the laptop is delivered.

The lab is a fully local and open-source stack built around a single-node Kubernetes environment with components such as Keycloak, SPIRE, OpenBao or Vault, MinIO, and OpenFGA. My preferred option is to run it inside a local virtual machine on the Orange laptop, because this gives the cleanest and most portable runtime model for later reuse on Orange Proxmox or OpenStack.

Could you please confirm which of the following options is allowed or preferred on the Orange laptop:

1. A local VM runtime, ideally through Hyper-V if available.
2. WSL 2 only, for Linux tooling and possibly lighter local execution.
3. No local virtualization, in which case I would target Orange-hosted Proxmox or OpenStack instead.

If possible, I would also like to know:

1. Whether Hyper-V is enabled or can be enabled on the laptop.
2. Whether WSL 2 is allowed.
3. Whether Orange provides an internal Proxmox or OpenStack environment that can be used for this lab.
4. Any policy constraints regarding local virtualization, nested virtualization, or container runtimes.

My goal is to choose the runtime model today so the lab remains usable from the office, customer sites, and travel situations, without depending on my personal infrastructure.

Thank you,

Jean Florentin
