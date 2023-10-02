{
  config,
  lib,
  ...
}:
with lib; {
  networking.nftables.ruleset = ''
    table inet global {
      chain input_public {
        # TODO: stop opportunistic DNS resolution

        tcp dport { 22, 53 } accept
        udp dport { 53, 68, 546 } accept
      }

      chain input_private {
        # Allow DHCPv4
        meta nfproto ipv4 udp dport 67 accept

        # allow ssh, dns, ntp
        tcp dport { 22, 53 } accept
        udp dport { 53, 123 } accept
      }

      chain input_basic {
        # Allow DHCPv4
        meta nfproto ipv4 udp dport 67 accept

        # allow dns, ntp
        tcp dport 53 accept
        udp dport { 53, 123 } accept
      }

      chain input_isolate {
        # only allow packets arriving for DHCP
        meta nfproto ipv4 udp dport 67 accept

        # NTP
        udp dport 123 accept
      }

      chain input {
        type filter hook input priority 0; policy drop;

        ct state vmap { \
          invalid: drop, \
          established: accept, \
          related: accept, \
        }

        icmp type echo-request accept
        icmpv6 type != { nd-redirect, 139 } accept comment "Accept all ICMPv6 messages except redirects and node information queries (type 139).  See RFC 4890, section 4.4."

        iifname vmap {
          lo: accept, \
          internet: jump input_public, \
          lan: jump input_private, \
          untrustedap: jump input_isolate, \
          iot: jump input_basic \
        } accept
      }

      chain forward_out_only {
        oifname internet accept
        drop
      }

      chain allow_forwarding_to_lan {
        oifname lan accept
        drop
      }

      chain forward {
        type filter hook forward priority 0; policy drop;

        ct state vmap { \
          invalid: drop, \
          established: accept, \
          related: accept, \
        }
        icmp type echo-request accept
        icmpv6 type != { router-renumbering, 139 } accept comment "Accept all ICMPv6 messages except renumbering and node information queries (type 139).  See RFC 4890, section 4.3."

        iifname vmap { \
          lan: accept, \
          untrustedap: jump forward_out_only, \
          internet: jump allow_forwarding_to_lan, \
        }
      }

      chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # masquerade anything heading out of ipv4 to the internet
        meta nfproto ipv4 meta oifname internet masquerade
      }
    }
  '';
}
