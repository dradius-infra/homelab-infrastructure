# Network Troubleshooting Runbook & Cheatsheet (RouterOS, Linux & macOS)

A structured Layer 1 through Layer 7 diagnostic runbook for MikroTik RouterOS, Linux/Proxmox virtualization hosts, and macOS administrative endpoints.

---

## 1. Safety & Operational Guardrails

- **Read-Only First:** Prioritize non-intrusive inspection commands before issuing flush, reset, deletion, or configuration-change commands.

- **Change Management:** Back up or export the current configuration before modifying production systems. Record the intended change, expected impact, validation procedure, and rollback plan.

- **Impact of Flushes:** Avoid flushing ARP caches or connection tracking tables on production environments without understanding the potential impact on active sessions, VoIP traffic, NAT mappings, and network performance.

- **Authorized Testing:** Perform diagnostics only against systems and networks you own or are authorized to administer. Connectivity probes may generate logs or trigger security monitoring.

- **Sensitive Artifacts:** Packet captures (`.pcap`), terminal dumps, and diagnostic exports may contain MAC addresses, internal/external IP addresses, DNS queries, authentication headers, and application payloads. Store securely and sanitize before public distribution.

- **Secret Isolation:** Use sanitized placeholders such as `<COMMUNITY_STRING>`, `<TARGET_IP>`, and `<PUBLIC_HOSTNAME>` in public documentation. Never commit private keys, passwords, API tokens, real SNMP community strings, or other credentials.

- **Version Validation:** Verify command syntax and behavior against the target RouterOS, Linux distribution, and macOS version before execution.

- **Production Safety:** Prefer controlled tests, maintenance windows, and explicit rollback procedures when troubleshooting live infrastructure.

---

## 2. Layer 1 & 2: Physical Link, Switching & ARP

### 2.1. Physical Link & Interface Health

Before evaluating Layer 2 or Layer 3 logic, verify physical link negotiation, interface state, and error counters.

#### MikroTik RouterOS

```routeros
# Inspect Ethernet negotiation, link duplex, and rate
/interface ethernet monitor ether5 once

# Inspect interface status and counters
/interface ethernet print stats

# Review interface configuration and operational state
/interface ethernet print detail
```

**Investigation checklist:**

- Is the interface running?
- Is the negotiated speed expected?
- Is the duplex mode correct?
- Are RX/TX errors or excessive drops increasing?
- Is the physical link flapping?
- Are the correct cables and ports being used?

---

### 2.2. Bridge VLAN Filtering & Trunk Inspection

#### MikroTik RouterOS

```routeros
# Verify bridge port configuration
# Includes PVID, frame types, and ingress filtering
/interface bridge port print detail

# Inspect VLAN membership
# Verify tagged and untagged ports
/interface bridge vlan print detail

# Inspect active bridge forwarding database (FDB)
/interface bridge host print where bridge=bridge-main

# Review bridge configuration
/interface bridge print detail
```

**VLAN troubleshooting checklist:**

- Confirm the correct PVID on access ports.
- Confirm trunk ports accept tagged frames as intended.
- Verify tagged and untagged membership for every VLAN.
- Check ingress filtering and frame-type restrictions.
- Confirm the switch and access point use matching VLAN IDs.
- Verify that the management VLAN is reachable only through intended paths.
- Check whether the bridge CPU port is included in VLAN membership when required for router VLAN interfaces.

**Common symptoms:**

| Symptom | Possible causes |
|---|---|
| Client receives no DHCP address | Wrong PVID, VLAN mismatch, trunk configuration, DHCP issue |
| Client receives an IP from the wrong subnet | Incorrect access VLAN or untagged/native VLAN mismatch |
| Management VLAN inaccessible | Incorrect tagged membership, PVID, firewall, or host configuration |
| Wireless SSID has no connectivity | AP VLAN tagging mismatch, trunk issue, DHCP or firewall configuration |

---

### 2.3. ARP Inspection & Neighbor Discovery

ARP inspection helps identify Layer 2 address-resolution problems within an IPv4 broadcast domain.

#### MikroTik RouterOS

```routeros
# Safe: Review ARP entries and resolution information
/ip arp print detail

# Filter unresolved or failed entries when supported
/ip arp print where status="failed" or status="incomplete"
```

**Interpretation note:**

ARP and neighbor-state labels depend on the platform and implementation. Do not assume that one status alone proves a specific root cause. Validate the entry together with interface state, IP addressing, VLAN configuration, and connectivity tests.

**Common indicators:**

- `incomplete`: Address resolution has not completed successfully.
- `failed`: Resolution attempts have failed according to the platform's state handling.
- `stale` or similar cached states: May indicate an entry that has not recently been refreshed; this is not automatically an outage.

#### Remediation — Use With Caution

```routeros
# Remove dynamic ARP entries
# WARNING: May temporarily disrupt address resolution
# and increase ARP traffic during re-resolution.
/ip arp remove [find dynamic=yes]
```

Use only when the impact is understood and a targeted alternative is not sufficient. Prefer inspecting and correcting the underlying problem before flushing a production cache.

#### Linux / Proxmox

```bash
# Display neighbor cache in a compact format
ip -br neigh show

# Display neighbors for a specific interface
ip neigh show dev eth0

# Flush neighbor cache on a specific interface
# Use only when necessary and with awareness of impact
sudo ip neigh flush dev eth0
```

#### macOS

```bash
# Display ARP cache
arp -a

# Delete a specific ARP entry
# Requires appropriate privileges
sudo arp -d <TARGET_IP>
```

---

## 3. Layer 3: Routing, DHCP & Path Diagnostics

### 3.1. Routing & FIB Selection

Routing inspection determines which route is selected for a destination.

#### MikroTik RouterOS

```routeros
# Display active routes
/ip route print detail where active=yes

# Display all routes with status flags
/ip route print detail

# Inspect the route selected for a destination
/ip route check <DESTINATION_IP>
```

#### Linux

```bash
# Display routing table
ip route show

# Determine route selection for a destination
ip route get 1.1.1.1
```

#### macOS

```bash
# Display IPv4 routing table
netstat -nr -f inet

# Determine routing path for a destination
route get 1.1.1.1
```

**Common routing flags on RouterOS:**

- `A`: Active
- `C`: Connected
- `S`: Static
- `D`: Dynamic

Interpret route flags in the context of the actual RouterOS version and routing configuration.

---

### 3.2. DHCP Server Diagnostics

Verify that clients receive the correct address, subnet mask, gateway, and DNS settings.

#### MikroTik RouterOS

```routeros
# Inspect DHCP leases
/ip dhcp-server lease print detail

# Check DHCP server status and interfaces
/ip dhcp-server print detail

# Inspect address pools
/ip pool print detail

# Inspect subnet gateway and DNS distribution
/ip dhcp-server network print detail
```

**Troubleshooting checklist:**

- Does the client receive an IP address?
- Is the address from the expected VLAN subnet?
- Is the default gateway correct?
- Is the DNS server correct?
- Is the DHCP server attached to the intended VLAN interface?
- Is the VLAN trunk/access configuration correct?
- Are static leases associated with the correct MAC address?

---

### 3.3. Path MTU & Fragmentation Discovery

Path MTU tests help identify packet-size limitations. A 1472-byte ICMP payload plus 28 bytes of IPv4 and ICMP headers corresponds to a 1500-byte IPv4 packet.

#### MikroTik RouterOS

```routeros
# Probe a 1500-byte IPv4 packet without fragmentation
/ping 1.1.1.1 size=1472 do-not-fragment count=4
```

#### Linux

```bash
# Probe PMTU using the Don't Fragment flag
ping -c 4 -M do -s 1472 1.1.1.1
```

#### macOS

```bash
# Probe PMTU using the Don't Fragment flag
ping -c 4 -D -s 1472 1.1.1.1
```

**Important:**

- A failed probe does not automatically establish the exact MTU.
- ICMP filtering or destination behavior can affect results.
- VPN tunnels may require smaller packet sizes because of encapsulation overhead.
- Test with progressively smaller payloads when investigating a suspected MTU issue.

---

## 4. Layer 4: Stateful Firewall, VPN & Service Discovery

### 4.1. Firewall Filtering & Connection Tracking

#### MikroTik RouterOS

```routeros
# Inspect firewall rules and packet/byte counters
/ip firewall filter print stats

# Inspect NAT rules and counters
/ip firewall nat print stats

# Inspect active connection tracking entries
/ip firewall connection print

# Filter connection entries containing a destination port
# Verify output against the actual RouterOS version
/ip firewall connection print where dst-address~":53"
```

**Troubleshooting checklist:**

- Identify whether traffic reaches the router.
- Inspect rule counters before and after a controlled test.
- Check input, forward, and output chains separately.
- Verify the order of filter and NAT rules.
- Check connection tracking state.
- Consider FastTrack behavior when troubleshooting traffic that requires special processing or inspection.

**Operational note:**

Avoid changing or clearing firewall/connection-tracking state on production systems without understanding the expected impact on active connections.

---

### 4.2. WireGuard Tunnel Diagnostics

#### MikroTik RouterOS

```routeros
# Inspect WireGuard peers, handshakes, and transfer metrics
/interface wireguard peers print detail

# Inspect WireGuard interface configuration
/interface wireguard print detail
```

#### Linux / macOS

```bash
# Display WireGuard interface status
# Includes latest handshake and transfer counters
sudo wg show
```

**Interpretation note:**

An old handshake timestamp does not automatically indicate an outage if no traffic has traversed the tunnel.

When active traffic fails, compare:

- Latest handshake timestamp
- Transmitted and received byte counters
- Endpoint reachability
- UDP port forwarding and firewall configuration
- Allowed IPs and routing
- Public/private key pairs
- `PersistentKeepalive` configuration where relevant

If transmitted bytes increase while received bytes remain static, investigate endpoint reachability, return routing, firewall behavior, NAT traversal, and peer configuration.

---

### 4.3. Protocol-Aware Service Verification

Raw UDP port checks are not reliable application-level availability tests. Prefer protocol-aware verification when possible.

#### TCP Connectivity

```bash
# TCP connection probe
# May generate connection attempts and server-side logs
nc -zv <TARGET_IP> 8291       # Winbox
nc -zv <TARGET_IP> 3000       # Grafana UI
nc -zv <TARGET_IP> 9090       # Telemetry backend
```

**Note:** `nc -zv` is a connectivity probe, not a guarantee that the application is healthy or correctly configured.

#### DNS Verification

```bash
# Query an explicit DNS resolver
dig @<DNS_SERVER_IP> example.com +short

# Query a public resolver for comparison
dig @1.1.1.1 example.com +short
```

#### SNMP Verification

```bash
# SNMPv2c application-aware query
# Use only with an authorized SNMP agent
snmpwalk -v2c -c <COMMUNITY_STRING> <TARGET_IP> 1.3.6.1.2.1.1
```

**SNMP security note:**

SNMPv2c community strings are not encrypted. Prefer SNMPv3 with authentication and privacy when supported and appropriate. Do not expose real community strings in command history, documentation, or public repositories.

#### Linux Host Socket Inspection

```bash
# Display listening TCP/UDP sockets and owning processes
ss -tulpn
```

---

## 5. Live Traffic Inspection & Packet Capture

### 5.1. MikroTik Torch (Real-Time Flow Telemetry)

```routeros
# Monitor traffic on an interface or VLAN
/tool torch interface=<VLAN_INTERFACE>

# Filter traffic for a specific source address
/tool torch interface=<VLAN_INTERFACE> src-address=<SOURCE_IP>/32
```

**Operational considerations:**

- Limit the monitoring scope where possible.
- Avoid unnecessary long-running captures on constrained hardware.
- Treat observed IP addresses and traffic metadata as sensitive information.
- Verify whether the traffic is visible on the chosen interface and at the chosen processing stage.

---

### 5.2. Controlled Packet Capture

#### MikroTik RouterOS

```routeros
# Configure packet capture output
/tool sniffer set file-name=capture.pcap filter-interface=<INTERFACE>

# Start capture
/tool sniffer start

# Reproduce the issue during a controlled test

# Stop capture
/tool sniffer stop
```

**Security and performance notice:**

Packet captures can contain unencrypted application payloads, DNS queries, internal addressing metadata, and sensitive information. Captures may also consume CPU, memory, and storage.

- Capture only the traffic needed for diagnosis.
- Keep capture duration and file size under control where supported.
- Store captures securely.
- Sanitize or delete captures before public distribution.
- Do not publish credentials, tokens, or private user data.

#### Linux

```bash
# Capture targeted traffic to a PCAP file
sudo tcpdump -ni eth0 host <TARGET_IP> and port <PORT> -w capture.pcap

# Inspect DNS traffic without writing a capture file
sudo tcpdump -ni any port 53 -nn
```

---

## 6. Layer 7: DNS & Application Webhooks

### 6.1. DNS Resolution & Cache Invalidation

#### DNS Query Tools

```bash
# Query a specific internal resolver
dig @<DNS_SERVER_IP> example.com +short

# Query a public resolver for comparison
dig @1.1.1.1 example.com +short

# Reverse DNS lookup
dig @<GATEWAY_IP> -x <TARGET_IP> +short
```

#### Local DNS Cache Invalidation

```bash
# macOS: Flush local DNS caches
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux with systemd-resolved
sudo resolvectl flush-caches
```

**Note:** DNS cache flushing is system- and resolver-dependent. Verify the active resolver implementation before applying a cache-clearing command.

---

### 6.2. Pi-hole & DNS Fallback Diagnostics

For networks using Pi-hole as the internal DNS resolver, test the resolver directly and compare it with an external resolver.

```bash
# Query Pi-hole directly
dig @<PIHOLE_IP> example.com

# Query public DNS for comparison
dig @1.1.1.1 example.com

# Inspect response and query timing
dig @<DNS_SERVER_IP> example.com
```

**Diagnostic interpretation:**

| Observation | Possible next checks |
|---|---|
| Pi-hole responds, client cannot resolve | DHCP DNS settings, firewall, client resolver configuration |
| Pi-hole does not respond | Host availability, DNS service, VLAN reachability, firewall |
| Public DNS works, Pi-hole fails | Pi-hole service, upstream connectivity, filtering configuration |
| Router DNS works but clients fail | Client DHCP configuration, forced DNS rules, routing, firewall |

**Fallback design note:**

If automated fallback is used, verify that monitoring, NAT rules, DNS configuration, and recovery behavior remain consistent. Test both failure and recovery paths rather than assuming the failover is working.

---

### 6.3. Webhook & Egress HTTPS Testing

```bash
# Verify HTTPS connectivity and inspect TLS handshake
curl -Iv https://api.telegram.org

# Display HTTP status and total request time
curl -s -o /dev/null \
  -w "HTTP Status: %{http_code} | Total Time: %{time_total}s\n" \
  https://api.telegram.org
```

**Interpretation note:**

- Successful TCP/TLS connectivity does not guarantee application-level success.
- HTTP status codes must be interpreted according to the endpoint.
- Avoid including authentication headers, tokens, or sensitive response data in public logs.
- Test only authorized endpoints and services.

---

## 7. VLAN Isolation & Connectivity Test Matrix

Use an explicit test matrix to validate the intended security policy.

| Source | Destination | Expected behavior |
|---|---|---|
| MAIN | Internet | Allow |
| MAIN | IoT | Allow according to policy |
| GUEST | MGMT | Deny |
| GUEST | LAB | Deny |
| Admin workstation | Proxmox | Allow only permitted services |
| LAB | MGMT | Allow or deny according to policy |
| VPN authorized peer | MAIN | Allow according to policy |

**Validation procedure:**

1. Run the test from the source VLAN.
2. Verify the destination and protocol/port.
3. Inspect firewall counters before and after the test.
4. Confirm that the result matches the intended policy.
5. Record unexpected behavior and investigate routing, NAT, or filtering.

Expected results must reflect the actual deployed firewall policy, not just the desired design.

---

## 8. Proxmox & Linux Host Diagnostics

### 8.1. Interface & Addressing

```bash
# Display interface addresses in compact format
ip -br addr

# Display interface state and configuration
ip link show

# Display routing table
ip route show

# Check route selection for a destination
ip route get 1.1.1.1
```

### 8.2. Services & Logs

```bash
# Check service status
systemctl status <SERVICE_NAME>

# View recent service logs
journalctl -u <SERVICE_NAME> -n 100 --no-pager

# Follow service logs in real time
journalctl -u <SERVICE_NAME> -f
```

### 8.3. Listening Services

```bash
# List listening sockets and associated processes
ss -tulpn
```

**Host networking checklist:**

- Confirm interface state and IP configuration.
- Verify the correct default gateway.
- Check VLAN-aware bridge configuration when applicable.
- Verify VM/CT network interface attachment.
- Confirm firewall settings at the host and router.
- Inspect service status and relevant logs.

---

## 9. Diagnostic Decision Flow

```text
                  [End-to-End Connectivity Loss]
                                |
                     Check Physical Link (L1)
                                |
                     Link Up / Link Down?
                      /                 \
                 LINK UP             LINK DOWN
                    |                     |
          Check IP Configuration    Cable / Port /
          & Gateway (L3)             Interface / Hardware
                    |
              Ping Gateway IP
                /          \
           SUCCESS        FAILURE
              |              |
      Ping Public IP    Inspect L2/L3:
      (e.g., 1.1.1.1)  ARP, VLAN, IP,
          /      \      Interface, Firewall
      SUCCESS  FAILURE
         |        |
     Check DNS   Inspect routing,
     (L7)        NAT, filter rules,
                 and WAN reachability
```

**Important:** ICMP failure alone does not establish a Layer 2 fault. Check firewall behavior, destination reachability, routing, and interface state before determining the root cause.

---

## 10. Change Management & Operational Workflow

Before applying a change to a live network:

1. Export or back up the current configuration.
2. Document the intended change and expected impact.
3. Confirm that a rollback procedure is available.
4. Apply one logical change at a time.
5. Validate connectivity, routing, VLAN behavior, and firewall policy.
6. Inspect logs and counters where relevant.
7. Record the outcome and any follow-up actions.

### Configuration Safety Checklist

- [ ] Configuration backup or export completed
- [ ] Change scope documented
- [ ] Rollback procedure available
- [ ] Test performed against authorized systems
- [ ] Expected connectivity verified
- [ ] Firewall/NAT behavior verified
- [ ] Sensitive outputs sanitized
- [ ] Documentation updated

---

## 11. Public Documentation & Repository Safety

Before publishing troubleshooting outputs or configuration examples:

- Remove private keys and credentials.
- Replace real SNMP community strings with placeholders.
- Remove authentication tokens and API secrets.
- Sanitize packet captures and terminal output.
- Review hostnames, public IP addresses, and identifying metadata.
- Avoid publishing unnecessary personal or network information.
- Verify that code blocks and Markdown syntax render correctly.
- Confirm that commands match the target platform and version.

**Recommended public placeholders:**

```text
<ROUTER_IP>
<TARGET_IP>
<DNS_SERVER_IP>
<PIHOLE_IP>
<COMMUNITY_STRING>
<INTERFACE>
<SERVICE_NAME>
<PORT>
```

---

## 12. Version & Compatibility Notes

Commands and output formats may differ between:

- MikroTik RouterOS versions
- Linux distributions and kernel versions
- macOS versions
- Network interface names
- Installed diagnostic utilities

Validate command availability and syntax before execution. When documenting a version-specific behavior, include the relevant software version and any required prerequisites.

---

## 13. Suggested Troubleshooting Entry Template

Use this template when adding new scenarios.

### Scenario: <PROBLEM_DESCRIPTION>

**Symptom**

Describe the observed behavior.

**Environment**

- Device / operating system:
- VLAN / subnet:
- Source and destination:
- Protocol / port:
- Time of occurrence:

**Possible Causes**

- Cause 1
- Cause 2
- Cause 3

**Diagnostic Commands**

```bash
# Read-only inspection commands
<COMMAND_1>
<COMMAND_2>
```

**Expected Findings**

Explain what the commands should show when the system is functioning correctly.

**Interpretation**

Describe how different outputs narrow down the possible root cause.

**Resolution**

Document the corrective action, required privileges, and possible impact.

**Validation**

Explain how to confirm that the issue has been resolved.

**Rollback**

Document how to revert the change if necessary.

---

## 14. Scope & Limitations

This runbook is a practical starting point for network troubleshooting across Layers 1–7.

It is not a substitute for:

- Vendor documentation
- Environment-specific change procedures
- Security policies
- Production maintenance processes
- Full packet analysis
- Application-specific diagnostics
- Incident response procedures

Always validate commands and interpretations against the actual environment, software version, and network design.