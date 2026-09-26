# Homelab Network Changelog

Incident records, architectural overhauls, and security hardening on a RouterOS core router.

---

## 2026-08-27 — Cross-VLAN Screen Mirroring (mDNS Reflector)

* **Impact:** Workstation laptop on the MAIN LAN could not detect or cast to the Smart TV located on the IoT segment.
* **Root Cause:** Discovery traffic such as mDNS does not normally cross Layer 3 subnet boundaries, so the workstation could not discover the TV on the IoT VLAN.
* **Resolution:**

  * Enabled an mDNS repeater/reflector between the MAIN and IoT interfaces.
  * Added firewall filter rules allowing the MAIN workstation to establish stateful streaming sessions into the IoT segment while keeping unsolicited inbound traffic from IoT blocked.

---

## 2026-09-15 — Subnet Overlap and L3 Bridge Decoupling

* **Impact:** Intermittent connectivity, packet loss, and routing conflicts across management devices.
* **Root Cause:** Two overlapping subnets were assigned to the same physical domain: an overlapping subnet directly on the main bridge and a conflicting mask on the management VLAN. Multiple DHCP server instances were competing over the same wire, causing lease races and routing ambiguity.
* **Resolution:**

  * Removed all Layer 3 IP configurations, DHCP pools, and DHCP servers directly attached to the bridge.
  * Configured the bridge strictly as a Layer 2 switch fabric with VLAN filtering enabled.
  * Terminated all default gateways exclusively on dedicated VLAN interfaces.

---

## 2026-09-15 — Switch Management IP Drift and DHCP Scopes

* **Impact:** Web and SSH management access to the core managed switch dropped intermittently or collided with other endpoints.
* **Root Cause:** The switch management interface requested dynamic DHCP leases without a static mapping, while the management DHCP pool lacked reservations for core infrastructure.
* **Resolution:**

  * Created a static DHCP reservation bound to the switch MAC address on the management VLAN.
  * Restricted the dynamic scope on the management pool to high host addresses, reserving low IPs exclusively for static infrastructure.
  * Cleared an erroneous static host route pointing the switch address back to the gateway interface.

---

## 2026-09-17 — Bridge Port Frame Types and Trunk Hardening

* **Impact:** Risk of VLAN leakage and untagged traffic crossing security boundary interfaces.
* **Root Cause:** The trunk uplink port connecting to the managed switch lacked frame ingress filtering. Access ports also accepted tagged frames from client endpoints.
* **Resolution:**

  * Enforced ingress filtering across all access ports, admitting only untagged/priority-tagged frames with explicit PVID assignments.
  * Locked down the switch uplink port to admit strictly 802.1Q tagged frames, preventing native VLAN leaks and hopping vectors.

---

## 2026-09-19 — DNS Interception Loops and Netwatch Failover

* **Impact:** Total network-wide internet loss whenever the primary DNS container went down for maintenance. Hardcoded devices (smart TVs, streaming hardware) bypassed local DNS policies.
* **Root Cause:**

  * No automated health-check mechanism existed to fall back to upstream resolvers if the primary sinkhole failed.
  * Intercepting all outbound port 53 traffic caused routing loops where the DNS container intercepted its own upstream queries.
* **Resolution:**

  * Configured automated health-check probing on port 53 against the sinkhole. If queries fail, an automated trigger switches system DNS to upstream public resolvers and disables NAT redirection, restoring filtering once the host recovers.
  * Enforced destination NAT redirection across all local VLAN interfaces for external port 53 UDP/TCP traffic.
  * Added drop rules preventing the sinkhole host from redirecting queries back into itself.

---

## 2026-09-20 — Firewall Redesign — Default Drop

* **Impact:** Legacy firewall policies allowed unrestricted lateral access between IoT and the primary LAN, with management interfaces exposed across internal subnets.
* **Root Cause:** Implicit-allow topology relying on fragmented permit rules instead of an explicit default-deny baseline.
* **Resolution:**

  * **Input Chain:** Restricted router management access strictly to designated admin IPs and the VPN tunnel, followed by an unconditional drop on all remaining traffic.
  * **Forward Chain:** Severed lateral movement from IoT and Guest networks. The MAIN LAN can initiate stateful connections to IoT, but IoT cannot reach MAIN. Guest networks are restricted strictly to WAN egress. Both chains terminate with an explicit default drop.

---

## 2026-09-20 — Layer 2 Hardening, Rate Limiting, and Service Cleanup

* **Impact:** Plaintext management daemons were exposed, and stale configurations left unused VPN endpoints active.
* **Root Cause:** Unused legacy services remained active by default, and legacy experimental tunnel configurations were left running in parallel.
* **Resolution:**

  * Configured reply-only ARP on the management interface to reduce the risk of unauthorized or incorrectly configured hosts using unassigned addresses.
  * Added token-bucket rate limits on ICMP traffic to limit excessive probing and unnecessary router load.
  * Disabled unencrypted management services (Telnet, FTP, plain API) and purged deprecated tunnel interfaces.
