# Network Infrastructure Documentation: HomeLab & Production

## 1. Document Metadata
- **Author:** [dradius](https://github.com/dradius-infra)
- **Role:** Network Administrator / Engineer
- **Environment:** HomeLab & SOHO Production
- **Status:** Active / In-Progress Reconfiguration

---
## 2. High-Level Architecture Overview
- **Primary Function:** [profesional SOHO production and lab experimenting ]
- **Topology Type:** Router-on-a-Stick / Layer 2 Trunked
- **Upstream ISP:** Cosmote (Speedport Gateway)
- **Core Router / Firewall:** MikroTik hEX S (RouterOS v7)
- **Core Switch:** TP-Link Omada ES208GP
- **Wireless Infrastructure:** MikroTik hAP ax²
- **Hypervisor / Services Host:** GMKtec M7 Ultra  32GB (Proxmox VE)

---
## 3. Physical Hardware Inventory

| Device Name         | Role / Function              | Model / Specs                             | Management IP  | MAC Address     |
| :------------------ | :--------------------------- | :---------------------------------------- | :------------- | :-------------- |
| **ISP Modem**       | Upstream WAN Gateway         | Cosmote Speedport Plus                    | 192.168.1.1/24 | *not mentioned* |
| **Core Router**     | L3 Routing, NAT, Firewall    | MikroTik hEX S (RB760iGS)                 | 10.10.10.1/27  | *not mentioned* |
| **Access Switch**   | L2 802.1Q Managed PoE Switch | TP-Link Omada ES208GP v1                  | 10.10.10.2/27  | *not mentioned* |
| **Access Point**    | Wi-Fi 6 AP (CAPsMAN/Bridge)  | MikroTik hAP ax²                          | 10.10.10.3/27  | *not mentioned* |
| **Hypervisor Host** | Virtualization / Lab Host    | GMKtec M7 Ultra (Ryzen 7 PRO 6850U, 32GB) | 10.10.10.4/27  | *not mentioned* |

---
## 4. Physical Port & Cabling Matrix (L1 Interconnects)

### MikroTik hEX S (Core Router)
**Management IP:** 10.10.10.1/27

- **Port ether1:** Uplink προς Speedport LAN (Subnet: 192.168.1.0/24 - Masquerade NAT)
- **Port ether2:** Access Port (PVID 10 - MGMT VLAN)
- **Port ether3:** Access Port (PVID 20 - MAIN VLAN)
- **Port ether4:** Access Port (PVID 30 - IOT VLAN)
- **Port ether5:** 802.1Q Trunk Uplink προς TP-Link ES208GP (Tagged: VLAN 10, 20, 30, 40, 50)
- **Port SFP1:** Unused / Reserved

### TP-Link Omada ES208GP (Core Switch)
**Management IP:** 10.10.10.2/27

- **Port 1:** 802.1Q Trunk Uplink προς MikroTik hEX S (Port ether5)
- **Port 2:** Access Port (PVID 10 - MGMT VLAN)
- **Port 3:** Access Port (PVID 20 - MAIN VLAN)
- **Port 4:** Access Port (PVID 20 - MAIN VLAN)
- **Port 5:** Access Port (PVID 30 - IOT VLAN)
- **Port 6:** Access Port (PVID 30 - IOT VLAN)
- **Port 7:** **Trunk / Tagged Uplink** (Tagged σε VLANs `10, 20, 30, 40, 50`, Native/PVID: 40)
- **Port 8:** 802.1Q Trunk Downlink προς MikroTik hAP ax² (Tagged: VLAN 10, 20, 30, 50)

**VLAN 1: Factory Default Native VLAN (Active on ports 1-8). Planned for hardening: Change native VLAN on uplinks and isolate management strictly to VLAN 10.

---

## 5. Wireless Infrastructure (MikroTik hAP ax²)

### Physical Connectivity & Mode
- **Mode:** Access Point / L2 Bridge (All routing/DHCP offloaded to hEX S)
- **Management IP:** 10.10.10.3/27
- **Uplink Interface:** ether1 (802.1Q Trunk connected to TP-Link Switch Port 8)
- **Power Source:** Passive PoE 24V

### SSID to VLAN Mapping Matrix

| SSID Name    | Targeted Audience        | Mapped VLAN     | Security / Encryption  | Frequency Band  | Client Isolation           |
| :----------- | :----------------------- | :-------------- | :--------------------- | :-------------- | :------------------------- |
| **nika.lan** | Trusted Personal Devices | VLAN 20 (MAIN)  | WPA2/WPA3-PSK          | 2.4 GHz + 5 GHz | Disabled                   |
| **nika.iot** | Smart Home & Embedded    | VLAN 30 (IOT)   | WPA2-PSK Only (Legacy) | 2.4 GHz Only    | Optional / Enabled         |
| **nika.dmz** | Guests / Untrusted       | VLAN 50 (GUEST) | WPA2/WPA3-PSK          | 2.4 GHz + 5 GHz | Enabled (Client Isolation) |

### Radio & RF Policies
- **2.4 GHz Band:** 20 MHz channel width (Non-overlapping channels: 1, 6, ή 11) for IoT compatibility.
- **2.4 GHz/5 GHz Band:** 80 MHz channel width for high throughput on `nika.lan` and `nika.dmz`

### Multicast & Discovery Features
- **mDNS Gateway / Cross-VLAN Discovery:** Active (Enables Apple AirPlay & discovery from `nika.lan` [VLAN 20] tο Smart TV on `nika.iot` [VLAN 30]).

---

## 6. Logical Addressing & IPAM Schema (Layer 3)

| VLAN ID | Subnet Name | Subnet / CIDR  | Default Gateway | Usable Host Range | DHCP Pool Range          | Role / Description                    |
| :------ | :---------- | :------------- | :-------------- | :---------------- | :----------------------- | :------------------------------------ |
| **-**   | **WAN**     | 192.168.1.0/24 | 192.168.1.1     | .2 - .254         | Static IP: 192.168.1.200 | Upstream ISP Double-NAT link          |
| **10**  | **MGMT**    | 10.10.10.0/27  | 10.10.10.1      | .2 - .30          | 10.10.10.10 - .30        | Network Infrastructure Management     |
| **20**  | **MAIN**    | 10.10.20.0/26  | 10.10.20.1      | .2 - .62          | 10.10.20.10 - .62        | Trusted PCs, Mac, Laptops             |
| **30**  | **IOT**     | 10.10.30.0/26  | 10.10.30.1      | .2 - .62          | 10.10.30.10 - .62        | Smart TVs, ESP32, Home Automation     |
| **40**  | **LAB**     | 10.10.40.0/24  | 10.10.40.1      | .2 - .254         | 10.10.40.10 - .254       | Virtual Machines & Testing Containers |
| **50**  | **GUEST**   | 10.10.50.0/26  | 10.10.50.1      | .2 - .62          | 10.10.50.10 - .62        | Isolated Guest Network                |

### Critical Static Reservations
- **10.10.10.1:** MikroTik hEX S (Core Gateway)
- **10.10.10.2:** TP-Link ES208GP (Managed Switch)
- **10.10.10.3:** MikroTik hAP ax² (Access Point)
- **10.10.10.4:** Proxmox VE Host (GMKtec M7)
- **10.10.10.5:** Pi-hole Primary DNS Host
- **10.10.20.10:** Admin MacBook (Primary Management Workstation)

---

## 7. Network Services & DNS Architecture

### Core Services Matrix

| Service                   | Host Machine                 | IP Address       | Port(s)    | Redundancy / Failover           |
| :------------------------ | :--------------------------- | :--------------- | :--------- | :------------------------------ |
| **DHCP Server**           | MikroTik hEX S               | 10.10.Χ.1        | UDP 67/68  | Local Gateway per VLAN          |
| **Primary DNS (AdBlock)** | Proxmox LXC (Pi-hole)        | 10.10.10.5       | UDP/TCP 53 | Monitored by MikroTik Netwatch  |
| **Fallback Upstream DNS** | External (Cloudflare/Google) | 1.1.1.1, 8.8.8.8 | UDP/TCP 53 | Auto-failover on Pi-hole outage |
| **VPN Engine**            | MikroTik hEX S               | 10.10.99.1       | UDP 13231  | WireGuard Remote Ingress        |
| **NTP Client**            | MikroTik hEX S               | Local RouterOS   | UDP 123    | Timezone: Europe/Athens         |

### DNS Resolution & Failover Flow

#### Normal State (Pi-hole Healthy)

- All VLANs receive their local Gateway IP (`10.10.X.1`) as the primary DNS server via DHCP options.
- The MikroTik hEX S captures and redirects inbound DNS queries to the dedicated Pi-hole instance (`10.10.10.5`).
- Pi-hole inspects and filters ad/tracker domains, resolving upstream queries through Cloudflare (`1.1.1.1`).
#### Failover State (Netwatch Automated Action)

- **Health Check Probe:** The MikroTik Netwatch tool monitors host `10.10.10.5` via ICMP ping every 10 seconds (`interval=10s`, `timeout=1s`).
    
- **On Down Event:** If Pi-hole fails to respond, an automated script executes immediately:
    
    - Overrides system DNS resolvers on the hEX S to public fallbacks (`1.1.1.1, 8.8.8.8`).
    - Disables the forced DNS NAT redirection rules to prevent traffic blackholing.
    - Writes a warning entry to the system log (`Pi-hole DOWN: Switched to Cloudflare DNS`).
        
- **On Up Event:** Once host `10.10.10.5` recovers:
    
    - Restores upstream DNS target back to `10.10.10.5`.
    - Re-enables the destination NAT filtering rules.
    - Logs state restoration (`Pi-hole UP: DNS filtering active`).

---

## 8. Security Policy & Inter-VLAN Firewall Matrix

### Forwarding Access Policy

| Source VLAN         | Destination VLAN  | Allowed Traffic / Ports                    | Action     | Business Justification / Purpose                      |
| :------------------ | :---------------- | :----------------------------------------- | :--------- | :---------------------------------------------------- |
| **VLAN 10 (MGMT)**  | ALL VLANs & WAN   | ANY / ALL                                  | **ACCEPT** | Full Administrative Access across all segments        |
| **VLAN 20 (MAIN)**  | VLAN 10 (MGMT)    | Selected Ports (WinBox, SSH, Web, Proxmox) | **ACCEPT** | Daily Admin Management (Restricted to Admin Mac's ip) |
| **VLAN 20 (MAIN)**  | VLAN 30 (IOT)     | AirPlay, Cast, Media Streaming             | **ACCEPT** | Local control of Smart TV and IoT endpoints           |
| **VLAN 20 (MAIN)**  | VLAN 40 (LAB)     | SSH, HTTP/S, Testing Ports                 | **ACCEPT** | Lab testing & VM management                           |
| **VLAN 20 (MAIN)**  | WAN (Internet)    | HTTP/S, DNS, Standard Outbound             | **ACCEPT** | Production Internet Access                            |
| **VLAN 30 (IOT)**   | WAN (Internet)    | Outbound NTP, Cloud Telemetry              | **ACCEPT** | Firmware updates & vendor cloud services              |
| **VLAN 30 (IOT)**   | Any Internal VLAN | None (Established/Related only)            | **DROP**   | Strict IoT quarantine                                 |
| **VLAN 40 (LAB)**   | WAN (Internet)    | Package Repos, Updates                     | **ACCEPT** | Linux package management                              |
| **VLAN 50 (GUEST)** | WAN (Internet)    | Web Browsing (80, 443), DNS (53)           | **ACCEPT** | Guest internet access only                            |
| **VLAN 50 (GUEST)** | Any Internal VLAN | NONE                                       | **DROP**   | Total guest isolation from private resources          |
| **ANY**             | ANY               | Unmatched Traffic                          | **DROP**   | Implicit Default Drop Policy (Zero-Trust baseline)    |

### Router Ingress Protection (Input Chain)

- **Drop Invalid:** Immediately discards all malformed, corrupted, or out-of-sequence packets (invalid state).
- **DNS Interception:** Allows DNS queries (ports 53 UDP/TCP) to the router exclusively from authorized internal networks (`VLANS` list).
- **Management Access:** Administrative access to RouterOS (WinBox, SSH, WebFig) is strictly restricted to `VLAN10_MGMT` and authorized IPs within `VLAN20_MAIN`.
- **VPN Ingress:** Opens only port `UDP 13231` on the WAN interface to terminate incoming WireGuard tunnels.
- **Drop All Other:** Enforces a Zero-Trust default policy by dropping any incoming host-bound packet that does not match an explicit allow rule.

