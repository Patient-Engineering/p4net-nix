{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.p4net;
in {
  options.services.p4net = {
    enable = mkEnableOption "p4net vpn";
    privateKeyFile = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        Wireguard private keyfile
      '';
    };
    instances = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = lib.mdDoc ''
              Name of the interface
            '';
          };
          listenPort = mkOption {
            type = types.ints.unsigned;
            default = 51820;
            description = lib.mdDoc ''
              Port number for wireguard to listen on
            '';
          };
          ips = mkOption {
            type = types.listOf types.str;
            description = lib.mdDoc ''
              List of IPs for the interface
            '';
          };
          allowedIPsAsRoutes = mkOption {
            type = types.bool;
            default = true;
            description = lib.mdDoc ''
              If wg-quick should add route per allowedIPs
            '';
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
          extraPostSetup = {
            type = types.str;
            default = "";
            description = lib.mdDoc ''
              Extra commands executed after interface goes up
            '';
          };
          extraPostShutdown = {
            type = types.str;
            default = "";
            description = lib.mdDoc ''
              Extra commands executed after interface goes down
            '';
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    networking.wireguard.interfaces = builtins.mapAttrs (name: icfg: let
      routes = builtins.filter (r: r != null) (map (pcfg: pcfg.route) icfg.peers);
      concatLines = (lines: concatStringsSep "\n" lines);
    in {
      ips = icfg.ips;
      privateKeyFile = cfg.privateKeyFile;
      listenPort = icfg.listenPort;

      peers = map (pcfg: {
        publicKey = pcfg.publicKey;
        allowedIPs = pcfg.allowedIPs;
        endpoint = pcfg.endpoint;
        persistentKeepalive = 25;
      }) icfg.peers;

      allowedIPsAsRoutes = icfg.allowedIPsAsRoutes;
      postSetup = concatLines (map (r: "${pkgs.iproute2}/bin/ip route add ${r} dev ${name}") routes) icfg.extraPostSetup;
      postShutdown = concatLines (map (r: "${pkgs.iproute2}/bin/ip route del ${r}") routes) icfg.extraPostShutdown;
    }) cfg.instances;

    networking.firewall = {
      allowedUDPPorts = map (icfg: icfg.listenPort) (builtins.attrValues cfg.instances);
    };
  };
}
