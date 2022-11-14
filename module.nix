{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.p4net;
in {
  options.services.p4net = {
    enable = mkEnableOption "p4net vpn";
    instances = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
          };
          ips = mkOption {
            type = types.str;
          };
          listenPort = mkOption {
            type = types.ints.unsigned;
            default = 51820;
          };
          privateKeyFile = mkOption {
            type = types.str;
          };
          peers = mkOption {
            type = types.listOf (types.submodule {
              options = {
                publicKey = mkOption {
                  type = types.str;
                };
                allowedIPs = mkOption {
                  type = types.listOf types.str;
                };
                endpoint = mkOption {
                  type = types.str;
                };
              };
            });
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    networking.wg-quick.interfaces = builtins.mapAttrs (name: icfg: {
      address = [icfg.ips];
      privateKeyFile = icfg.privateKeyFile;
      listenPort = icfg.listenPort;

      peers = map (pcfg: {
        publicKey = pcfg.publicKey;
        allowedIPs = pcfg.allowedIPs;
        endpoint = pcfg.endpoint;
        persistentKeepalive = 25;
      }) icfg.peers;

      # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
      postUp = ''
        ${pkgs.iproute2}/bin/ip route add ${icfg.ips} dev ${name}
      '';

      # Undo the above
      preDown = ''
        ${pkgs.iproute2}/bin/ip route del ${icfg.ips}
      '';
    }) cfg.instances;

    networking.firewall = {
      allowedUDPPorts = map (icfg: icfg.listenPort) (builtins.attrValues cfg.instances);
    };
  };
}
