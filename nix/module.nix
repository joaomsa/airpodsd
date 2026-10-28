{ config, lib, pkgs, ... }:

let
  cfg = config.services.airpodsd;
in {
  options.services.airpodsd = {
    enable = lib.mkEnableOption "AirPods battery reporting through BlueZ";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The airpodsd package to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      settings.General.Experimental = true;
    };

    environment.systemPackages = [ cfg.package ];

    # A single system-wide daemon owns the upstream abstract status socket.
    # Start/stop it with BlueZ, including when bluetooth.service is restarted.
    systemd.services.airpodsd = {
      description = "AirPods battery provider for BlueZ";
      wantedBy = [ "bluetooth.service" ];
      requires = [ "bluetooth.service" ];
      after = [ "bluetooth.service" ];
      partOf = [ "bluetooth.service" ];
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} daemon /var/lib/airpodsd/keystore";
        Restart = "always";
        RestartSec = "5s";
        StateDirectory = "airpodsd";
        StateDirectoryMode = "0700";
        UMask = "0077";
        # Upstream's abstract status socket is accessible to local users.
        # Bound resource use, including incomplete/unbounded status requests.
        MemoryMax = "256M";
        TasksMax = 64;
        LimitNOFILE = 256;
        # Root can register a provider on the system BlueZ bus without adding
        # permissive D-Bus policies. Bound privileges to Bluetooth networking.
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
