# Local Hypervisor Decision For The Orange Laptop

## Decision summary

Preferred order for the Orange laptop:

1. Hyper-V, if available and allowed by Orange policy.
2. WSL 2 as a secondary Linux runtime option for tooling and light local lab work, but not the first choice for the full portable VM model.
3. VirtualBox, only if Hyper-V is unavailable and VirtualBox is approved.
4. VMware Workstation, only if it is already the enterprise standard or specifically approved.
5. No local hypervisor fallback: use Orange Proxmox or OpenStack as the runtime target.

Current status:
1. Preferred direction: real VM runtime on the Orange laptop if policy allows it.
2. Secondary path kept open: WSL 2 for tooling and light local work until Orange confirms the final laptop policy.

## Why Hyper-V is the preferred default

1. Native on Windows Enterprise or Pro.
2. Better fit for corporate laptops and offline use.
3. Cleaner integration with Windows networking and virtualization features.
4. Good choice for a single-node portable lab VM.

## Why VirtualBox is third choice

1. Common and easy to understand.
2. Works well for portable single-node labs.
3. More likely than VMware to be acceptable without extra licensing.

Limits:
1. Corporate approval may still block it.
2. Networking behavior can be less predictable on locked-down enterprise endpoints.

## Where WSL fits

1. WSL 2 is not the same thing as the full Hyper-V feature.
2. WSL 2 uses the `Virtual Machine Platform` feature, which is a subset of Hyper-V architecture.
3. On this current Windows 11 station, `wsl --status` reports WSL 2 with Debian as the default distribution.
4. On this current Windows 11 station, `Microsoft-Hyper-V-All` is disabled while `VirtualMachinePlatform` and `Microsoft-Windows-Subsystem-Linux` are enabled.
5. This proves the practical point: full Hyper-V is not required for WSL 2 to be available.
6. WSL is a valid option for Linux-native tooling, scripts, and even a lightweight Kubernetes inner loop.
7. WSL is not the preferred primary answer for this lab's portable runtime because the lab target is a movable autonomous VM image, and WSL behaves less like a traditional standalone VM.

Use WSL when:
1. You need Linux tooling on Windows quickly.
2. You want a lightweight fallback for authoring, testing scripts, or validating Kubernetes manifests.
3. Orange policy allows WSL but blocks a full desktop hypervisor.
4. You want to keep Windows as the host while running the IaC and Kubernetes toolchain in a Linux userland.

Do not treat WSL as the first-choice runtime when:
1. You need a portable VM artefact that maps cleanly to Proxmox, Hyper-V, and OpenStack.
2. You need behavior closer to a conventional Linux VM for demos, export, or handoff.

## Practical implication for this lab

1. WSL 2 is a strong candidate for the tooling plane on the Orange laptop.
2. It is weaker as the primary runtime plane for the full lab if the goal is to move one VM-shaped artefact between targets.
3. So the current recommendation remains: use WSL if it helps with local Linux tooling, but prefer a real VM runtime when the laptop and policy allow it.

## Why VMware Workstation is not the default

1. It is solid technically.
2. In practice it is only attractive if Orange already standardizes on it.
3. Otherwise it adds approval and packaging friction without a clear advantage for this lab.

## No local hypervisor fallback

If the Orange laptop cannot run a local VM, the next best option is not home Proxmox. It is Orange-hosted Proxmox or OpenStack, because that remains reachable from office and customer-site contexts through enterprise paths.

## Decision matrix

| Option | Mobility | Corporate fit | Offline autonomy | Complexity | Recommendation |
|---|---|---|---|---|---|
| Hyper-V | High | High if enabled | High | Medium | First choice |
| WSL 2 | High | High if approved | Medium | Low | Good secondary option |
| VirtualBox | High | Medium | High | Medium | Fallback |
| VMware Workstation | High | Medium | High | Medium | Only if standard |
| No local hypervisor | Medium | High | Low | Low | Only if laptop restrictions force it |

## Immediate recommendation before Thursday

1. Keep building the lab as a portable VM with k3s.
2. Do not hard-wire anything to Proxmox-only behavior.
3. As soon as the Orange laptop arrives, verify whether Hyper-V is available.
4. If Hyper-V is blocked but WSL is allowed, use WSL for tooling and light validation while checking whether a full local VM path is still possible.
5. If no full local VM path is available, test whether Orange provides Proxmox or OpenStack before investing time in a second desktop hypervisor.
