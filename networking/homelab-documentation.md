# Network Infrastructure Documentation: Enterprise Homelab & Security Architecture

## 1. Document Metadata
- **Author:** dradius
- **Environment:** Production Homelab & Security Architecture
- **Framework:** Zero-Trust Micro-segmentation & Defense-in-Depth
- **Status:** Production-Hardened

---

## 2. High-Level Architecture Overview
- **Primary Function:** Segmented SOHO Infrastructure, Observability Telemetry & Isolated Hypervisor Lab
- **Topology Type:** Router-on-a-Stick / 802.1Q Hardware Bridge VLAN Filtering
- **Core Edge Router:** MikroTik RouterOS v7 Appliance
- **Core Distribution Switch:** Managed 8-Port Gigabit 802.1Q PoE Switch
- **Wireless Infrastructure:** Dual-Band Wi-Fi 6 Access Point (Bridge Mode)
- **Virtualization & Workloads:** Bare-Metal Hypervisor (Proxmox VE)

---

## 3. Physical Hardware Inventory

| Device Role | Function | Platform / Specs | Logical Subnet | Management Interface | Physical Addressing |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Edge Gateway** | Upstream WAN Demarcation | Carrier Demarcation Device | 192.168.1.0/24 | 192.168.1.1 | *REDACTED* |
| **Core Router** | L3 Routing, NAT, Stateful Firewall | RouterOS v7 Appliance | 10.10.10.0/27 | 10.10.10.1 | *REDACTED* |
| **Core Switch** | L2 Managed Distribution | 8-Port Managed PoE Switch | 10.10.10.0/27 | 10.10.10.2 | *DYNAMIC_DHCP_ARP* |
| **Access Point** | 802.11ax L2 Trunk Bridge | Dual-Band Wi-Fi 6 AP | 10.10.10.0/27 | 10.10.10.3 | *DYNAMIC_DHCP_ARP* |
| **Hypervisor Host** | Bare-Metal Virtualization Core | 8C/16T x86_64, 32GB RAM (Proxmox) | 10.10.10.0/27 | 10.10.10.4 | *DYNAMIC_DHCP_ARP* |

---

## 4. Physical Port & Cabling Matrix (L1 Interconnects)

### Core Router
**Management Interface:** 10.10.10.1/27

- **Port ether1:** Uplink to ISP Gateway LAN (Subnet: 192.168.1.0/24 - Outbound Masquerade NAT)
- **Port ether2:** Access Port (`pvid=10` - Out-of-Band MGMT Fallback, `admit-only-untagged-and-priority-tagged`)
- **Port ether3:** Access Port (`pvid=20` - Trusted Workstation Port, `admit-only-untagged-and-priority-tagged`)
- **Port ether4:** Access Port (`pvid=30` - Isolated IoT Access, `admit-only-untagged-and-priority-tagged`)
- **Port ether5:** 802.1Q Inter-Switch Trunk Uplink (`admit-only-vlan-tagged`, Tagged: VLAN 10, 20, 30, 40, 50)
- **Port SFP1:** Reserved / Inactive

### Core Switch
**Management Interface:** 10.10.10.2/27

- **Port 1:** 802.1Q Trunk Uplink to Core Router (`ether5`)
- **Port 2:** Access Port (`PVID 10` - MGMT Secondary)
- **Port 3 - 4:** Access Ports (`PVID 20` - Trusted Workstations)
- **Port 5 - 6:** Access Ports (`PVID 30` - IoT Infrastructure)
- **Port 7:** 802.1Q Trunk to Hypervisor Host (Tagged: VLAN 10, 20, 30, 40, 50)
- **Port 8:** 802.1Q Trunk Downlink to Access Point (Tagged: VLAN 10, 20, 30, 50)

*L2 Hardening: Native VLAN 1 is explicitly disabled across all trunk links; management operations are isolated to VLAN 10.*

---

## 5. Power Delivery & Infrastructure Resilience

Core routing and infrastructure appliances are protected by a centralized Uninterruptible Power Supply (UPS):

- **Topology:** Line-Interactive Pure Sine Wave UPS (900VA / 540W)
- **Protected Hardware:** WAN Modem, Core Router, Distribution Switch, Hypervisor Host, Primary Workstation Dock
- **Estimated Runtime:**
  - **Full Operational Load (~140W):** ~18–25 minutes
  - **Network-Only Essential Load (~40W):** ~55–70 minutes

---

## 6. Wireless Infrastructure & SSID Mapping

### Architecture & RF Policies
- **Operating Mode:** Layer 2 Transparent Bridge (Routing and DHCP services terminated at Core Gateway)
- **2.4 GHz Band:** 20 MHz channel width (Non-overlapping channels: 1, 6, or 11) for embedded legacy hardware.
- **5 GHz Band:** 80 MHz channel width for high-throughput trusted devices.

### SSID Segregation Matrix

| SSID | Intended Devices | 802.1Q Mapped VLAN | Security Protocol | Client Isolation |
| :--- | :--- | :--- | :--- | :--- |
| **corp-net** | Trusted Workstations & Personal Hardware | VLAN 20 (MAIN) | WPA2/WPA3-Personal (SAE) | Disabled |
| **iot-net** | Smart Home & Embedded Peripherals | VLAN 30 (IOT) | WPA2-PSK (AES-only) | Enabled |
| **guest-net** | Untrusted / Visitor Devices | VLAN 50 (GUEST) | WPA2/WPA3-Personal | **Enabled (L2 Air-Gap)** |

---

## 7. Logical Addressing & IPAM Schema (Layer 3)

| VLAN ID | Subnet Name | CIDR Prefix | Default Gateway | Usable Host Range | DHCP Pool Range | Role / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **-** | **WAN** | 192.168.1.0/24 | 192.168.1.1 | .2 - .254 | Static ISP Ingress | Upstream WAN Transit |
| **10** | **MGMT** | 10.10.10.0/27 | 10.10.10.1 | .2 - .30 | 10.10.10.20 - .30 | Out-of-Band Management & Core Services |
| **20** | **MAIN** | 10.10.20.0/26 | 10.10.20.1 | .2 - .62 | 10.10.20.10 - .62 | Trusted Personal Hardware (ARP-Hardened) |
| **30** | **IOT** | 10.10.30.0/26 | 10.10.30.1 | .2 - .62 | 10.10.30.10 - .62 | Micro-segmented IoT Devices |
| **40** | **LAB** | 10.10.40.0/24 | 10.10.40.1 | .2 - .254 | 10.10.40.10 - .254 | Hypervisor Virtual Workloads & Sandboxes |
| **50** | **GUEST** | 10.10.50.0/26 | 10.10.50.1 | .2 - .62 | 10.10.50.10 - .62 | Isolated Guest Network |
| **-** | **VPN** | 10.10.99.0/24 | 10.10.99.1 | .2 - .254 | Static Cryptographic Allocation | Remote Ingress WireGuard Tunnels |

### Critical Infrastructure Allocations
- **10.10.10.1:** Core Router Virtual Gateway
- **10.10.10.2:** Core Switch Management Interface
- **10.10.10.3:** Access Point Management Interface
- **10.10.10.4:** Bare-Metal Hypervisor (Proxmox VE Host)
- **10.10.10.5:** Dedicated DNS Sinkhole (Pi-hole Service)
- **10.10.10.10:** NetFlow / Observability Collector (ntopng)
- **10.10.20.10:** Authorized Management Workstation (Bound Static ARP)

---

## 8. Network Services & High-Availability Telemetry

### Infrastructure Services Matrix

| Service | Host Interface | Logical IP | Port / Protocol | Operational Mechanism |
| :--- | :--- | :--- | :--- | :--- |
| **Stateful DHCP** | Core Router | 10.10.X.1 | UDP 67/68 | Local Gateway per Segment (`add-arp=yes` enforced) |
| **L7 Filtered DNS** | Dedicated Host | 10.10.10.5 | UDP/TCP 53 | Enforced via Destination NAT & Selective Hairpin |
| **Emergency Fallback DNS** | Public Upstreams | 1.1.1.1, 8.8.8.8 | UDP/TCP 53 | Automated watchdog failover on sinkhole outage |
| **Flow Telemetry** | Telemetry Core | 10.10.10.10 | UDP 2055 | Active flow telemetry exported by RouterOS Traffic-Flow |
| **Remote Ingress** | Core Router | 10.10.99.1 | UDP `<VPN_LISTEN_PORT>` | Kernel-level WireGuard Tunnel Termination |

### Resilient Layer 7 DNS Failover Architecture
To prevent network-wide blackholing during DNS outages, the Core Router implements automated Layer 7 health monitoring:

1. **Active Filtering State:**
   - Client subnets are configured via DHCP to query their respective local gateway (`10.10.X.1`).
   - Destination NAT rules force all internal UDP/TCP port 53 traffic to the internal sinkhole (`10.10.10.5`).
   - Hairpin NAT masquerading is strictly constrained to `10.10.10.0/27`, preserving native client source IPs on all inter-VLAN DNS traffic for per-host logging.
2. **Automated L7 Health Probe:**
   - Netwatch performs Layer 7 health checks every 10 seconds against port 53 (`type=tcp-conn port=53 timeout=1s`).
3. **Failover Execution (Sinkhole Failure):**
   - If TCP connection establishment fails:
     - Upstream resolvers dynamically shift to public recursive servers (`1.1.1.1`, `8.8.8.8`).
     - Destination NAT redirection rules are automatically disabled.
     - Direct outbound DNS resolution to the WAN interface is permitted to sustain connectivity.
4. **State Restoration (Failback):**
   - Upon successful TCP socket connection, redirection rules re-enable and filtering resumes automatically.

---

## 9. Security Policy & Zero-Trust Firewall Matrix

### Forwarding Access Policy (Inter-VLAN Enforcement)

| Source Interface / Subnet | Destination | Protocol / Ports | Action | Security Justification / Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **DNS Self-Loop** | 10.10.10.5 | UDP/TCP 53 | **DROP** | Mitigates cascading reflection loops |
| **INTERNAL_VLANS** | 10.10.10.5 | UDP/TCP 53 | **ACCEPT** | Inter-VLAN DNS query forwarding |
| **Fallback Path** | ether1 (WAN) | UDP/TCP 53 | **ACCEPT** | Permitted exclusively during sinkhole failover |
| **INTERNAL_VLANS** | ether1 (WAN) | ANY | **ACCEPT** | Regulated outbound Internet access |
| **wireguard-vpn** | ether1 (WAN) | ANY | **ACCEPT** | Secure full-tunnel Internet access for VPN clients |
| **10.10.20.0/26 (MAIN)**| 10.10.10.4 (Proxmox) | ICMP (Ping) | **ACCEPT** | Hypervisor host diagnostics |
| **10.10.20.0/26 (MAIN)**| 10.10.10.4 (Proxmox) | TCP `<PROXMOX_SERVICES_PORTS>` | **ACCEPT** | Hypervisor administration (SSH, Web UI, API) |
| **10.10.20.10 (Admin)** | VLAN 40 (LAB) | ICMP (Ping) | **ACCEPT** | Administrative reachability diagnostics |
| **VLAN 20 (MAIN)** | VLAN 30 (IOT) | ANY | **ACCEPT** | Unidirectional session initiation (Media, Control) |
| **10.10.20.10 (Admin)** | VLAN 10 (MGMT) | ANY | **ACCEPT** | Direct workstation access to management infrastructure |
| **10.10.99.2 (VPN Mac)**| VLAN 20 (MAIN) | ANY | **ACCEPT** | Remote ingress restricted strictly to MAIN workstation zone |
| **VLAN 50 (GUEST)** | INTERNAL_VLANS | ANY | **DROP** | Explicit quarantine from all private resources |
| **ANY** | ANY | Unmatched Traffic | **DROP** | **Zero-Trust Baseline (Default Forward Deny)** |

### Router Ingress Protection (Input Chain)

- **Drop Invalid:** Immediately discards malformed, corrupted, or out-of-order packets.
- **Reconnaissance Suppression:** ICMP echo requests are permitted solely across `INTERNAL_VLANS`. External WAN ping sweeps receive no response.
- **Protocol Restraint:**
  - UDP 67 (DHCP) is restricted to `INTERNAL_VLANS`.
  - UDP/TCP 53 (DNS) is restricted to `INTERNAL_VLANS`.
  - Router management daemons (Winbox, SSH) are restricted at both firewall and service levels (`available-from`) strictly to trusted management subnets (`10.10.10.0/27`, `10.10.20.0/26`, `10.10.99.0/24`).
- **VPN Termination:** Exposes only `<VPN_LISTEN_PORT>` (UDP) on the WAN interface for authenticated WireGuard handshakes.
- **Default Drop Policy:** Silently discards all unmatched incoming traffic destined for the router host.

---

## 10. L2 Threat Mitigation & Anti-Spoofing Controls

1. **Hardware Bridge VLAN Filtering:**
   - Default native VLAN 1 is deactivated across all trunk paths.
   - Access interfaces enforce `frame-types=admit-only-untagged-and-priority-tagged` with explicit PVIDs to prevent VLAN hopping.
   - Inter-switch uplinks enforce `frame-types=admit-only-vlan-tagged` to discard untagged frames.
2. **Dynamic ARP Hardening (`arp=reply-only`):**
   - `VLAN20_MAIN` is configured with `arp=reply-only`.
   - The DHCP server dynamically populates authenticated IP leases into the router's ARP table (`add-arp=yes`).
   - Unauthorized static IP assignments fail ARP resolution, neutralizing IP spoofing vectors.
3. **Neighbor Discovery Restriction:**
   - MNDP, CDP, and LLDP discovery protocols are restricted strictly to `INTERNAL_VLANS`, preventing topology disclosures toward the WAN and Guest networks.