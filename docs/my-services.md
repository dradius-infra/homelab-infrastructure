# Proxmox VE Container Services Inventory

## 1. Document Metadata

* **Environment:** Proxmox VE
* **Framework:** LXCs & Network Micro-segmentation
* **Status:** Operational — Active Maintenance

---

## 2. Proxmox Container Inventory (LXC)

| VMID | Hostname / Role | Logical Subnet | IP Address / Binding | Purpose & Architecture Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **100** | **pihole** | MGMT (VLAN 10) | `<PIHOLE_IP>` | Primary L7 DNS resolution and ad-blocking. |
| **101** | **searxng** | MGMT (VLAN 10) | `<SEARXNG_IP>` | Privacy-respecting, self-hosted engine aggregating search results without tracking user data. |
| **102** | **grafana** | MGMT (VLAN 10) | `<GRAFANA_IP>` | Visualization, dashboards, and alerting backend. |
| **103** | **uptime-kuma** | MGMT (VLAN 10) | `<KUMA_IP>` | Monitoring tool for service uptime and endpoint health checks. |
| **104** | **mdns-reflector** | MGMT (VLAN 10) | `<REFLECTOR_IP>` | Layer 3 multicast DNS repeater bridging discovery across isolated VLAN segments. |
| **105** | **ntopng** | MGMT (VLAN 10) | `<NTOPNG_IP>` | High-speed network traffic collector and analyzer. |
| **106** | **homepage** | MGMT (VLAN 10) | `<HOMEPAGE_IP>` | Centralized static operational status dashboard. |
| **107** | **backup** | MGMT (VLAN 10) | `<BACKUP_HOST_IP>` | Automated configuration backup engine and local repository sync host. |
| **108** | **pi-alert** | MGMT (VLAN 10) | `<PIALERT_IP>` | Network device scanner and anomaly/presence detection utility. |

---

## 3. Security Design & LXC Isolation Principles

* **Unprivileged Execution:** All containers run as unprivileged LXCs preventing host kernel exploitation even if a container workload is compromised.
* **Management Zoning:** Every container resides strictly inside **VLAN 10**, isolating control planes from untrusted IoT, guest, or workstation traffic.
* **Stateful Egress Enforcement:** Inter-container and outbound traffic is governed by strict router firewall rules. 