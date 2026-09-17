# Network Infrastructure Documentation: HomeLab & Production

## 1. Document Metadata
- **Author:** dradius
- **Environment:** HomeLab & SOHO Production
- **Status:** Active / In-Progress Reconfiguration

---
## 2. High-Level Architecture Overview
- **Primary Function:** SOHO Production and Lab Experimenting
- **Topology Type:** Router-on-a-Stick / Layer 2 Trunked
- **Upstream ISP:** Generic Carrier Gateway
- **Core Router / Firewall:** MikroTik hEX S (RouterOS v7)
- **Core Switch:** Managed 8-Port Gigabit PoE Switch
- **Wireless Infrastructure:** Dual-Band Wi-Fi 6 Access Point
- **Hypervisor / Services Host:** Dedicated Virtualization Host (Proxmox VE)

---
## 3. Physical Hardware Inventory

| Device Name         | Role / Function              | Model / Specs                         | Management IP  | MAC Address     |
| :------------------ | :--------------------------- | :------------------------------------ | :------------- | :-------------- |
| **ISP Modem**       | Upstream WAN Gateway         | Carrier Demarcation Device            | 192.168.1.1/24 | *REDACTED*      |
| **Core Router**     | L3 Routing, NAT, Firewall    | RouterOS v7 Appliance                 | 10.10.10.1/27  | *REDACTED*      |
| **Access Switch**   | L2 802.1Q Managed PoE Switch | Managed 8-Port Switch                 | 10.10.10.2/27  | *REDACTED*      |
| **Access Point**    | Wi-Fi 6 AP (Bridge Mode)     | Dual-Band Wi-Fi 6 AP                  | 10.10.10.3/27  | *REDACTED*      |
| **Hypervisor Host** | Virtualization / Lab Host    | 8C/16T x86_64, 32GB RAM               | 10.10.10.4/27  | *REDACTED*      |

---
## 4. Physical Port & Cabling Matrix (L1 Interconnects)

### Core Router
**Management IP:** 10.10.10.1/27

- **Port ether1:** Uplink to ISP Gateway LAN (Subnet: 192.168.1.0/24 - Masquerade NAT)
- **Port ether2:** Access Port (PVID 10 - MGMT VLAN)
- **Port ether3:** Access Port (PVID 20 - MAIN VLAN)
- **Port ether4:** Access Port (PVID 30 - IOT VLAN)
- **Port ether5:** 802.1Q Trunk Uplink to Core Switch (Tagged: VLAN 10, 20, 30, 40, 50)
- **Port SFP1:** Unused / Reserved

### Core Switch
**Management IP:** 10.10.10.2/27

- **Port 1:** 802.1Q Trunk Uplink to Core Router (Port ether5)
- **Port 2:** Access Port (PVID 10 - MGMT VLAN)
- **Port 3:** Access Port (PVID 20 - MAIN VLAN)
- **Port 4:** Access Port (PVID 20 - MAIN VLAN)
- **Port 5:** Access Port (PVID 30 - IOT VLAN)
- **Port 6:** Access Port (PVID 30 - IOT VLAN)
- **Port 7:** **Trunk / Tagged Uplink** (Tagged: VLAN 10, 20, 30, 40, 50, Native/PVID: 40)
- **Port 8:** 802.1Q Trunk Downlink to Access Point (Tagged: VLAN 10, 20, 30, 50)

*Hardening Notice: Factory default native VLAN 1 is restricted across trunk links; all infrastructure management traffic is strictly isolated to VLAN 10.*

---

## 5. Power Delivery & Infrastructure Resilience

Critical network hardware and management workstations are backed up by a central uninterruptible power supply (UPS) to guarantee clean power delivery and prevent sudden power loss:

- **UPS Unit:** Line-Interactive Pure Sine Wave UPS
- **Rated Capacity:** 900VA / 540W
- **Connected Equipment:**
  - **Core Networking:**
    - WAN Demarcation Gateway
    - Core Router / Firewall
    - Managed Distribution Switch
    - Wireless Access Point
  - **Workstation & Display:**
    - Management Workstation Charger
    - Secondary Monitor / Auxiliary Display
- **Estimated Runtime:**
  - Full Active Load (~140W): **~18–25 minutes**
  - Network-Only / Idle Load (~40W): **~55–70 minutes**

---

## 6. Wireless Infrastructure

### Physical Connectivity & Mode
- **Mode:** Access Point / L2 Bridge (All routing and DHCP services offloaded to Core Router)
- **Management IP:** 10.10.10.3/27
- **Uplink Interface:** ether1 (802.1Q Trunk connected to Switch Port 8)
- **Power Source:** Dedicated DC Power Adapter

### SSID to VLAN Mapping Matrix

| SSID Name         | Targeted Audience        | Mapped VLAN     | Security / Encryption  | Frequency Band  | Client Isolation           |
| :---------------- | :----------------------- | :-------------- | :--------------------- | :-------------- | :------------------------- |
| **corp-net**      | Trusted Personal Devices | VLAN 20 (MAIN)  | WPA2/WPA3-PSK (SAE)    | 2.4 GHz + 5 GHz | Disabled                   |
| **iot-net**       | Smart Home & Embedded    | VLAN 30 (IOT)   | WPA2-PSK Only (Legacy) | 2.4 GHz Only    | Optional / Enabled         |
| **guest-net**     | Guests / Untrusted       | VLAN 50 (GUEST) | WPA2/WPA3-PSK          | 2.4 GHz + 5 GHz | Enabled (Client Isolation) |

### Radio & RF Policies
- **2.4 GHz Band:** 20 MHz channel width (Non-overlapping channels: 1, 6, or 11) for legacy IoT compatibility.
- **5 GHz Band:** 80 MHz channel width for high throughput on `corp-net` and `guest-net`.

### Multicast & Discovery Features
- **mDNS Gateway / Cross-VLAN Discovery:** Active (Restricted mDNS reflector enabling discovery from `corp-net` [VLAN 20] to target media receivers on `iot-net` [VLAN 30]).

---

## 7. Logical Addressing & IPAM Schema (Layer 3)

| VLAN ID | Subnet Name | Subnet / CIDR  | Default Gateway | Usable Host Range | DHCP Pool Range          | Role / Description                    |
| :------ | :---------- | :------------- | :-------------- | :---------------- | :----------------------- | :------------------------------------ |
| **-**   | **WAN**     | 192.168.1.0/24 | 192.168.1.1     | .2 - .254         | Static Ingress: .200     | Upstream ISP Link                     |
| **10**  | **MGMT**    | 10.10.10.0/27  | 10.10.10.1      | .2 - .30          | 10.10.10.10 - .30        | Network Infrastructure Management     |
| **20**  | **MAIN**    | 10.10.20.0/26  | 10.10.20.1      | .2 - .62          | 10.10.20.10 - .62        | Trusted Workstations                  |
| **30**  | **IOT**     | 10.10.30.0/26  | 10.10.30.1      | .2 - .62          | 10.10.30.10 - .62        | Smart Home & Embedded Peripherals     |
| **40**  | **LAB**     | 10.10.40.0/24  | 10.10.40.1      | .2 - .254         | 10.10.40.10 - .254       | Virtual Machines & Testing Containers |
| **50**  | **GUEST**   | 10.10.50.0/26  | 10.10.50.1      | .2 - .62          | 10.10.50.10 - .62        | Isolated Guest Network                |

### Critical Static Reservations
- **10.10.10.1:** Core Gateway
- **10.10.10.2:** Managed Switch
- **10.10.10.3:** Access Point
- **10.10.10.4:** Virtualization Host
- **10.10.10.5:** Internal DNS Host
- **10.10.20.10:** Authorized Management Workstation

---

## 8. Network Services & DNS Architecture

### Core Services Matrix

| Service                   | Host Machine                 | IP Address       | Port(s)         | Redundancy / Failover           |
| :------------------------ | :--------------------------- | :--------------- | :-------------- | :------------------------------ |
| **DHCP Server**           | Core Router                  | 10.10.X.1        | UDP 67/68       | Local Gateway per VLAN          |
| **Primary DNS (AdBlock)** | Hypervisor Host (DNS Sink)   | 10.10.10.5       | UDP/TCP 53      | Monitored via Automated Probe   |
| **Fallback Upstream DNS** | External Anycast Resolvers   | 1.1.1.1, 8.8.8.8 | UDP/TCP 53      | Auto-failover on DNS host down  |
| **VPN Engine**            | Core Router                  | 10.10.99.1       | UDP [CUSTOM_PORT]| WireGuard Remote Ingress       |
| **NTP Client**            | Core Router                  | Local Appliance  | UDP 123         | Timezone: UTC                   |

### DNS Resolution & Failover Flow

#### Normal State (DNS Sinkhole Active)
- All VLANs receive their local Gateway IP (`10.10.X.1`) as primary DNS via DHCP.
- The Core Router intercepts and redirects all inbound internal DNS traffic to the internal DNS sinkhole (`10.10.10.5`).
- The DNS host filters malicious/tracking domains and forwards clean upstream requests to secure external resolvers.

#### Failover State (Automated Watchdog)
- **Health Check Probe:** The router monitors `10.10.10.5` via ICMP ping probes every 10 seconds (`interval=10s`, `timeout=1s`).
- **On Down Event:** If the internal DNS sink fails to respond:
  - Overrides system DNS resolvers on the core router to public fallbacks (`1.1.1.1`, `8.8.8.8`).
  - Disables the destination NAT redirection rule to prevent traffic blackholing.
  - Logs an alert event to the administrative syslog buffer.
- **On Up Event:** Once `10.10.10.5` is reachable again:
  - Restores the internal resolver address.
  - Re-enables the destination NAT interception rules.
  - Logs state restoration.

---

## 9. Security Policy & Inter-VLAN Firewall Matrix

### Forwarding Access Policy

| Source VLAN | Destination VLAN | Allowed Traffic / Ports | Action | Business Justification / Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **VLAN 10 (MGMT)** | ALL VLANs & WAN | ANY / ALL | **ACCEPT** | Full Administrative Access across all segments |
| **VLAN 20 (MAIN)** | ALL VLANs | ANY / ALL | **ACCEPT** | Restricted strictly to Authorized Workstation IP (10.10.20.10) |
| **wireguard-vpn** | ALL VLANs & WAN | ANY / ALL | **ACCEPT** | Secure remote administrative access via VPN tunnel |
| **INTERNAL_VLANS** | DNS Host (10.10.10.5) | DNS (UDP/TCP 53) | **ACCEPT** | Direct internal resolution to dedicated DNS sinkhole |
| **VLAN 20 (MAIN)** | WAN (Internet) | HTTP/S, DNS, Standard Outbound | **ACCEPT** | Standard workstation Internet Access |
| **VLAN 30 (IOT)** | WAN (Internet) | Outbound NTP, Encrypted Cloud API | **ACCEPT** | Firmware updates & vendor cloud telemetry |
| **VLAN 30 (IOT)** | Any Internal VLAN | None (Established/Related only) | **DROP** | Strict IoT quarantine |
| **VLAN 40 (LAB)** | WAN (Internet) | Package Repositories, Updates | **ACCEPT** | Operating system package management |
| **VLAN 40 (LAB)** | Any Internal VLAN | NONE | **DROP** | Quarantine lab environment from production subnets |
| **VLAN 50 (GUEST)** | WAN (Internet) | Web Browsing (80, 443), DNS (53) | **ACCEPT** | Isolated guest access |
| **VLAN 50 (GUEST)** | Any Internal VLAN | NONE | **DROP** | Total guest isolation from all private resources |
| **ANY** | ANY | Unmatched Traffic | **DROP** | Default Drop Policy (Zero-Trust baseline) |

### Router Ingress Protection (Input Chain)

- **Drop Invalid:** Immediately discards all malformed, corrupted, or out-of-sequence packets.
- **DHCP Ingress:** Allows UDP port 67 strictly from authenticated internal VLAN interfaces.
- **DNS Interception:** Allows internal clients to query the router's DNS resolver solely across authorized subnets.
- **Management Access:** Management access (CLI, Web, API) is restricted strictly to `VLAN 10 (MGMT)`, the authorized workstation IP `10.10.20.10`, and authenticated WireGuard tunnel peers.
- **VPN Ingress:** Exposes only non-standard `UDP [CUSTOM_PORT]` on the WAN interface to terminate authenticated WireGuard tunnels.
- **Drop All Other:** Enforces a Zero-Trust default policy by silently dropping any unmatched incoming packet destined for the router host.