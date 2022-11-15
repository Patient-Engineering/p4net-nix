{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.p4net;
in {
  options.services.p4net = {
    enable = mkEnableOption "p4net vpn";
    ips = mkOption {
      type = types.str;
    };
    privateKeyFile = mkOption {
      type = types.str;
    };
    instances = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
          };
          listenPort = mkOption {
            type = types.ints.unsigned;
            default = 51820;
          };
          peers = mkOption {
            type = types.listOf (types.submodule {
              options = {
                route = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                publicKey = mkOption {
                  type = types.str;
                };
                allowedIPs = mkOption {
                  type = types.listOf types.str;
                };
                endpoint = mkOption {
                  type = types.nullOr types.str;
                  default = null;
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

    networking.wg-quick.interfaces = builtins.mapAttrs (name: icfg: let
      routes = builtins.filter (r: r != null) (map (pcfg: pcfg.route) icfg.peers);
      concatLines = (lines: concatStringsSep "\n" lines);
    in {
      address = [cfg.ips];
      privateKeyFile = cfg.privateKeyFile;
      listenPort = icfg.listenPort;

      peers = map (pcfg: {
        publicKey = pcfg.publicKey;
        allowedIPs = pcfg.allowedIPs;
        endpoint = pcfg.endpoint;
        persistentKeepalive = 25;
      }) icfg.peers;

      postUp = concatLines (map (r: "${pkgs.iproute2}/bin/ip route add ${r} dev ${name}") routes);
      preDown = concatLines (map (r: "${pkgs.iproute2}/bin/ip route del ${r}") routes);
    }) cfg.instances;

    networking.firewall = {
      allowedUDPPorts = map (icfg: icfg.listenPort) (builtins.attrValues cfg.instances);
    };
  };
}
