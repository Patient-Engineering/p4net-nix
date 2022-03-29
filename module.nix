{ lib, config, ... }:
with lib;
let
  cfg = config.services.p4net;
in {
  options.services.p4net = {
    enable = mkEnableOption "p4net vpn";
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

  config = mkIf cfg.enable {
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    networking.wireguard.interfaces = {
      p4net = {
        ips = [ cfg.ips ];
        privateKeyFile = cfg.privateKeyFile;
        listenPort = cfg.listenPort;

        peers = map (pcfg: {
          publicKey = pcfg.publicKey;
          allowedIPs = pcfg.allowedIPs;
          endpoint = pcfg.endpoint;
          persistentKeepalive = 25;
        }) cfg.peers;
      };
    };

    networking.firewall = {
      allowedUDPPorts = [ cfg.listenPort ];
    };
  };
}
