/ip firewall filter

#INPUT CHAIN
add chain=input action=accept connection-state=established,related,untracked comment="Accept established, related, untracked"
add chain=input action=drop connection-state=invalid comment="Drop invalid packets"
add chain=input action=accept protocol=udp dst-port=XXXXX comment="Allow WireGuard VPN Handshake"
add chain=input action=accept in-interface=wireguard-vpn comment="Allow WireGuard VPN to manage router"
add chain=input action=accept protocol=icmp comment="Allow ping for troubleshooting"
add chain=input action=accept protocol=udp dst-port=67 in-interface-list=INTERNAL_VLANS comment="Allow DHCP requests from VLANs"
add chain=input action=accept protocol=udp dst-port=53 in-interface-list=INTERNAL_VLANS comment="Allow DNS UDP from internal VLANs"
add chain=input action=accept protocol=tcp dst-port=53 in-interface-list=INTERNAL_VLANS comment="Allow DNS TCP from internal VLANs"
add chain=input action=accept in-interface=VLAN10_MGMT comment="Allow Management VLAN full access to router"
add chain=input action=accept src-address=10.10.20.10 in-interface=VLAN20_MAIN comment="Allow Admin Workstation to manage router"
add chain=input action=drop comment="Drop all other input"

#FORWARD CHAIN
add chain=forward action=fasttrack-connection connection-state=established,related in-interface=!wireguard-vpn out-interface=!wireguard-vpn comment="FastTrack"
add chain=forward action=accept connection-state=established,related,untracked comment="Accept established forward"
add chain=forward action=drop connection-state=invalid comment="Drop invalid forward"
add chain=forward action=accept dst-address=10.10.10.5 dst-port=53 protocol=udp in-interface-list=INTERNAL_VLANS comment="Allow DNS to Pi-hole UDP"
add chain=forward action=accept dst-address=10.10.10.5 dst-port=53 protocol=tcp in-interface-list=INTERNAL_VLANS comment="Allow DNS to Pi-hole TCP"
add chain=forward action=accept in-interface-list=INTERNAL_VLANS out-interface=ether1 comment="Allow Internet to all VLANs"
add chain=forward action=accept in-interface=VLAN10_MGMT comment="Allow MGMT to access all VLANs"
add chain=forward action=accept src-address=10.10.20.10 in-interface=VLAN20_MAIN comment="Allow Admin Workstation to access all VLANs"
add chain=forward action=accept in-interface=wireguard-vpn comment="Allow WireGuard VPN to access all VLANs and Internet"
add chain=forward action=drop comment="Drop all other forward traffic"