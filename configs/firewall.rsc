/ip firewall filter

# INPUT CHAIN (Router Hardening & Ingress)

add action=accept chain=input comment="Accept established, related, untracked" connection-state=established,related,untracked
add action=drop chain=input comment="Drop invalid packets" connection-state=invalid
add action=accept chain=input comment="Allow ping with rate limit" protocol=icmp limit=10,5:packet
add action=accept chain=input comment="Allow WireGuard VPN Handshake" dst-port=<VPN_LISTEN_PORT> protocol=udp
add action=accept chain=input comment="Allow authorized VPN client to manage router" in-interface=wireguard-vpn src-address=10.10.99.2
add action=accept chain=input comment="Allow DHCP requests from VLANs" dst-port=67 in-interface-list=INTERNAL_VLANS protocol=udp
add action=accept chain=input comment="Allow DNS UDP to local resolver" dst-port=53 in-interface-list=INTERNAL_VLANS protocol=udp
add action=accept chain=input comment="Allow DNS TCP to local resolver" dst-port=53 in-interface-list=INTERNAL_VLANS protocol=tcp
add action=accept chain=input comment="Allow Admin Workstation to manage router" in-interface=VLAN20_MAIN src-address=10.10.20.10
add action=accept chain=input comment="Allow Out-of-Band MGMT access to router" in-interface=VLAN10_MGMT
add action=drop chain=input comment="Drop all other input traffic"


# FORWARD CHAIN (Inter-VLAN & Micro-segmentation)

# DNS Loop Prevention for Pi-hole
add action=drop chain=forward comment="KILL PIHOLE SELF-LOOP UDP" dst-address=10.10.10.5 dst-port=53 protocol=udp src-address=10.10.10.5
add action=drop chain=forward comment="KILL PIHOLE SELF-LOOP TCP" dst-address=10.10.10.5 dst-port=53 protocol=tcp src-address=10.10.10.5

# Stateful Inspection & FastTrack
add action=fasttrack-connection chain=forward comment="FastTrack (Excluding WireGuard)" connection-state=established,related in-interface=!wireguard-vpn out-interface=!wireguard-vpn
add action=accept chain=forward comment="Accept established, related, untracked" connection-state=established,related,untracked
add action=drop chain=forward comment="Drop invalid forward packets" connection-state=invalid

# Core DNS Forwarding & Failover Paths
add action=accept chain=forward comment="Allow DNS to Pi-hole UDP" dst-address=10.10.10.5 dst-port=53 in-interface-list=INTERNAL_VLANS protocol=udp
add action=accept chain=forward comment="Allow DNS to Pi-hole TCP" dst-address=10.10.10.5 dst-port=53 in-interface-list=INTERNAL_VLANS protocol=tcp
add action=accept chain=forward comment="Allow Direct DNS to WAN when Pi-hole is down (UDP)" dst-port=53 out-interface=ether1 protocol=udp
add action=accept chain=forward comment="Allow Direct DNS to WAN when Pi-hole is down (TCP)" dst-port=53 out-interface=ether1 protocol=tcp

# Internet Access
add action=accept chain=forward comment="Allow WireGuard client full-tunnel Internet" in-interface=wireguard-vpn out-interface=ether1 src-address=10.10.99.2
add action=accept chain=forward comment="Allow Internet to all internal VLANs" in-interface-list=INTERNAL_VLANS out-interface=ether1

# Segmented Cross-VLAN Permissions (Least Privilege)
add action=accept chain=forward comment="Allow MAIN subnet ICMP to Proxmox Host" dst-address=10.10.10.4 in-interface-list=INTERNAL_VLANS out-interface=VLAN10_MGMT protocol=icmp src-address=10.10.20.0/26
add action=accept chain=forward comment="Allow MAIN subnet to Proxmox Services" dst-address=10.10.10.4 dst-port=<PROXMOX_SERVICES_PORTS> in-interface-list=INTERNAL_VLANS out-interface=VLAN10_MGMT protocol=tcp src-address=10.10.20.0/26
add action=accept chain=forward comment="Allow Admin Workstation ICMP to LAB" in-interface=VLAN20_MAIN out-interface=VLAN40_LAB protocol=icmp src-address=10.10.20.10
add action=accept chain=forward comment="Allow MAIN to initiate sessions to IoT" in-interface=VLAN20_MAIN out-interface=VLAN30_IOT
add action=accept chain=forward comment="Allow Admin Workstation full access to MGMT" in-interface=VLAN20_MAIN out-interface=VLAN10_MGMT src-address=10.10.20.10
add action=accept chain=forward comment="Allow WireGuard client access to MAIN VLAN" in-interface=wireguard-vpn out-interface=VLAN20_MAIN src-address=10.10.99.2

# Explicit Isolation & Default Deny
add action=drop chain=forward comment="Explicit: Drop Guest VLAN to Internal Networks" in-interface=VLAN50_GUEST out-interface-list=INTERNAL_VLANS
add action=drop chain=forward comment="Drop all other forward traffic"