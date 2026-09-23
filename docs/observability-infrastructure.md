# Observability & Monitoring Infrastructure: Homelab Architecture

## 1. Document Metadata

- **Author:** dradius
- **Environment:** Production Homelab Observability Architecture
- **Framework:** Zero-Trust Micro-segmentation & Least-Privilege Monitoring
- **Status:** Operational — Ongoing Hardening & Active Verification

---

## 2. High-Level Architecture Overview

- **Primary Function:** Dual-tier observability architecture providing real-time operational status (Homepage) alongside granular, long-term time-series telemetry and alerting (Grafana / Prometheus).
- **High-Level Status Tier:** Lightweight application dashboard consuming read-only REST APIs, scoped API tokens, and dedicated application secrets.
- **Deep-Dive Telemetry Tier:** Metric scraping pipeline via Prometheus leveraging host-level exporters (pull architecture) paired with cryptographic SNMPv3 queries and unidirectional NetFlow ingestion (push architecture).
- **Placement & Segmentation:** Telemetry services are deployed as isolated, unprivileged Linux Containers (LXCs) contained strictly within Management VLAN 10.
- **Security Model:** Enforced custom least-privilege policies, local IP ACL binding (`available-from`), dedicated API scopes, TLS encryption, and sanitized secret management.

---

## 3. Security Assumptions & Threat Modeling

### Security Assumptions
- The Management VLAN is treated as an isolated trust zone, but not assumed to be immune to lateral movement (zero-trust stance).
- Monitoring endpoints and dashboards are never exposed directly to the public Internet.
- All credentials, private tokens, and passphrases reside strictly in external secret stores/environment variables and are excluded from version control.
- Network boundaries and inter-VLAN quarantine policies are strictly enforced by stateful firewall filter rules on the core router.

### Threat Vector Mitigations
- **Compromised Monitoring Container:** Containers run unprivileged; egress is restricted to VLAN 10 plus strictly defined external NTP/DNS endpoints, significantly reducing lateral movement and pivoting risk.
- **Credential Eavesdropping:** Plaintext HTTP administrative surfaces are disabled; RouterOS REST API uses HTTPS (`www-ssl`), and SNMP relies on SNMPv3 User-based Security Model (USM) with AES encryption (`authPriv`).
- **Privilege Escalation via API:** Service accounts (MikroTik, Proxmox) are mapped to stripped-down custom profiles/tokens lacking write, policy-change, or reboot permissions.

---

## 4. Monitoring Platform Inventory

| Device / Container Role | Function | Platform / Engine | Logical Subnet | Management Endpoint | Ingestion Mechanism |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Monitoring Dashboard** | Operational Status & Service Catalog | Homepage (LXC) | 10.0.0.0/24 | 10.0.0.12:3000 | Asynchronous REST / JSON Polling |
| **Telemetry Analytics** | Time-Series Metrics & Alerts | Grafana & Prometheus (LXC) | 10.0.0.0/24 | 10.0.0.6:3000 / 9090 | Pull Scrape (Prometheus) / Dashboard Query |
| **Flow Telemetry Engine** | Network Flow Collection | ntopng / NetFlow Collector | 10.0.0.0/24 | 10.0.0.10:3000 | Asynchronous UDP Flow Records (Push) |
| **DNS Sinkhole** | L7 Name Resolution & Blocking | Pi-hole v6 (LXC) | 10.0.0.0/24 | 10.0.0.5 | Native v6 REST API Engine |
| **Virtualization Host** | Hypervisor Node | Proxmox VE (Bare-Metal) | 10.0.0.0/24 | 10.0.0.4:8006 | PVEAPIToken & node_exporter |
| **Core Router** | Edge Gateway & Routing | MikroTik RouterOS v7 | 10.0.0.0/24 | 10.0.0.1 | HTTPS REST API & SNMPv3 Exporter |
| **Access Point** | Wireless Bridge & AP | MikroTik RouterOS v7 | 10.0.0.0/24 | 10.0.0.3 | HTTPS REST API & SNMPv3 Exporter |

---

## 5. Telemetry Pipelines & Metric Collection

### 5.1. Tier 1: Real-Time Operational State (Homepage)
The high-level dashboard queries managed systems asynchronously through isolated, scoped control planes:

- **MikroTik RouterOS Integration:**
  - Polling runs against the native RouterOS v7 REST engine exclusively over HTTPS (port 443) with HTTP disabled.
  - Access is delegated to a dedicated service account bound to a custom RouterOS group containing only the required validated policies (`read`, `api`, `rest-api`). The `test` policy is explicitly excluded because it grants diagnostic and operational capabilities unnecessary for integration.
  - Effective permissions of the custom group are audited against active monitoring endpoints to prevent unintended privilege accumulation.
  - The system administration daemon (`www-ssl`) enforces ACL connection filtering (`available-from="10.0.0.0/24,<MGMT_WORKSTATION_IP>/32"`).

- **Proxmox VE Hypervisor Integration:**
  - Polled over HTTPS using an unprivileged API token (`<API_USER>@pam!<TOKEN_ID>`).
  - Token configuration avoids privilege escalation, assigning read-only access strictly to cluster resource mapping and node performance statistics.

- **Pi-hole v6 DNS Telemetry:**
  - Metrics are queried against the modular Pi-hole v6 REST API engine over HTTPS.
  - Destructive API capabilities (blocking adjustments, list modification) are disabled, restricting queries strictly to telemetry via scoped application tokens.

### 5.2. Tier 2: Granular Time-Series & Alerting (Grafana & Prometheus)
- **Host & OS Telemetry (`node_exporter`):**
  - Target endpoints expose system metrics (CPU saturation, storage I/O latency, memory utilization) on TCP port 9100.
  - Prometheus polls target hosts via scheduled pull scrape intervals.
  - Target firewall rules enforce that TCP port 9100 is reachable strictly from the Prometheus host IP (10.0.0.6).

- **Network Infrastructure Telemetry (`snmp_exporter`):**
  - Prometheus scrapes the `snmp_exporter`, which acts as a proxy querying MikroTik devices via SNMPv3 and converting records into Prometheus metrics.
  - Enforces cryptographic user-based security (`authPriv` with SHA256 authentication and AES encryption), mitigating cleartext eavesdropping across internal links.
  - Ingests interface throughput, duplex operational status, dropped/error counters, and hardware health metrics.

- **Alerting Engine:**
  - Prometheus Alertmanager evaluates and routes threshold alerts (interface flaps, exporter unreachability, continuous resource exhaustion) via structured notification channels.

---

## 6. Network Services & Monitoring Port Matrix

| Service Type | Source Workload | Destination Endpoint | Port / Protocol | Security Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **Web UI Dashboard** | Management Workstations | Homepage (10.0.0.12) | TCP 3000 | Centralized operational status catalog |
| **Web UI Telemetry** | Management Workstations | Grafana (10.0.0.6) | TCP 3000 | Deep-dive telemetry inspection & visualization |
| **Prometheus API/UI**| Management Workstations | Prometheus (10.0.0.6) | TCP 9090 | Metric inspection, target status, and debugging |
| **Router REST API** | Homepage (10.0.0.12) | Core Router (10.0.0.1) | TCP 443 | Encrypted resource extraction via HTTPS |
| **AP REST API** | Homepage (10.0.0.12) | Access Point (10.0.0.3) | TCP 443 | Encrypted wireless client and interface monitoring |
| **PVE API Polling** | Homepage (10.0.0.12) | Hypervisor (10.0.0.4) | TCP 8006 | Scoped virtual infrastructure metric polling |
| **Pi-hole API** | Homepage (10.0.0.12) | DNS Sinkhole (10.0.0.5) | TCP 443 | DNS query throughput and blocklist metrics |
| **Linux Node Metrics**| Prometheus (10.0.0.6) | Proxmox Host (10.0.0.4) | TCP 9100 | Kernel, storage, and node-level pull scraping |
| **SNMP Polling** | snmp_exporter (10.0.0.6)| Core Router (10.0.0.1) | UDP 161 | Cryptographic SNMPv3 infrastructure scraping |
| **SNMP Polling** | snmp_exporter (10.0.0.6)| Access Point (10.0.0.3) | UDP 161 | Cryptographic SNMPv3 AP interface telemetry |
| **Traffic Flow Ingest**| Core Router (10.0.0.1) | Flow Core (10.0.0.10) | UDP 2055 | IPFIX/NetFlow egress session telemetry push |

---

## 7. Zero-Trust Access & Firewall Containment

### Isolation Policy for Monitoring Workloads
- **Restricted Egress:** Both the Homepage container (`10.0.0.12`) and the Grafana/Prometheus container (`10.0.0.6`) are blocked from initiating connections outside VLAN 10, with exceptions strictly limited to local recursive DNS resolvers and external package mirrors/NTP via stateful inspection.
- **Inter-VLAN Quarantine:** Monitoring workloads cannot traverse or originate connections into client zones (VLAN 20), IoT devices (VLAN 30), or guest networks (VLAN 50).
- **Administrative Ingress:** Dashboard access (TCP ports 3000, 9090) is restricted to the designated administrative endpoint (`<MGMT_WORKSTATION_IP>/32`) and verified management operators.
- **Prometheus API/UI Protection:** Network-level containment is treated as an isolation barrier, not an identity provider. Prometheus API/UI access remains restricted to management workstations, with an authentication reverse proxy mandated if multi-user or broader internal access is introduced.

### Router Ingress Enforcement
- **Restricted Management Surface:** Unencrypted plain HTTP (`www`) is disabled. HTTPS (`www-ssl`) and SNMP services drop any packets originating outside authorized management prefixes.
- **Anti-Reconnaissance:** ICMP echo requests targeting router gateways on untrusted segments are dropped to minimize network discovery and fingerprinting.

---

## 8. Operational Validation & Diagnostics

### 8.1. API Ingestion Validation

```bash
# Verify RouterOS REST API output over HTTPS
curl -s --cacert /path/to/internal-ca.crt \
  -u "<MONITORING_USER>:<MONITORING_PASSWORD>" \
  https://10.0.0.1/rest/system/resource | jq .

# Verify Proxmox API cluster status
# (Note: Use --insecure ONLY during initial bootstrap if custom internal CA is not yet injected)
curl -s --cacert /path/to/pve-ca.pem \
  -H "Authorization: PVEAPIToken=<API_USER>@pam!<TOKEN_ID>=<API_TOKEN_SECRET>" \
  https://10.0.0.4:8006/api2/json/version | jq .

# Verify Pi-hole v6 API metrics reachability
curl -s -k \
  -H "sid: <APP_PASSWORD>" \
  https://10.0.0.5/api/stats/summary | jq .
```

### 8.2. Metric Exporter & Scrape Diagnostics

```bash
# Verify local Prometheus target registration and scrape status
curl -s http://10.0.0.6:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastScrape: .lastScrape}'

# Verify host node_exporter metric endpoint reachability (run from Prometheus host 10.0.0.6)
curl -s http://10.0.0.4:9100/metrics | grep -E "node_cpu_seconds_total|node_memory_MemAvailable_bytes"

# Validate cryptographic SNMPv3 transport to router
snmpwalk -v3 -l authPriv -u <SNMP_USER> \
  -a SHA256 -A "<AUTH_PASS>" \
  -x AES -X "<PRIV_PASS>" \
  10.0.0.1 1.3.6.1.2.1.1.1.0
```