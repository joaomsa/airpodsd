# airpodsd
A daemon (for Linux only) that exposes AirPods battery information to `bluez` through its [`org.bluez.BatteryProviderManager`](https://github.com/bluez/bluez/blob/master/doc/org.bluez.BatteryProviderManager.rst) D-Bus API. Now rewritten to support AirPods BLE advertisements as well!

If both the left and right bud battery levels are available, the average of both buds is reported. If only one of the left or right bud battery levels are available, it is reported directly. Otherwise, no battery level is reported at all.

`upower` based programs can also read this battery information as `upower` has a `bluez` backend for exposing battery information of Bluetooth devices.
As a result, AirPods battery information is shown just like any other Bluetooth device in the default system areas and is available to other power management utilities.

## Usage
Run `airpodsd daemon /path/to/keystore` in the background.

airpodsd will create the keystore file once it's needed to store BLE decryption keys.

## Nix / NixOS

This fork adds a standalone flake with packages for `x86_64-linux` and
`aarch64-linux`, plus a NixOS module. The Rust daemon is unchanged from upstream.

Build or inspect the command-line interface:

```sh
nix build github:joaomsa/airpodsd
nix run github:joaomsa/airpodsd -- --help
```

Add the input to your NixOS flake and import the module:

```nix
{
  inputs.airpodsd.url = "github:joaomsa/airpodsd";
  inputs.airpodsd.inputs.nixpkgs.follows = "nixpkgs";

  # Inside nixpkgs.lib.nixosSystem:
  # modules = [ inputs.airpodsd.nixosModules.default ./configuration.nix ];
}
```

Then enable it in your configuration:

```nix
services.airpodsd.enable = true;
```

The module enables Bluetooth and BlueZ's experimental battery-provider API,
installs the CLI, and runs one system-wide daemon alongside `bluetooth.service`.
It keeps BLE keys in `/var/lib/airpodsd/keystore`, inside a root-only state
directory, and restarts with BlueZ. Do not run a separate user daemon at the
same time: upstream uses one shared abstract Unix socket for status requests.
This status socket is accessible to all local users; the state-directory
permissions protect the keys, not the status interface. The service caps memory,
tasks, and file descriptors to contain upstream's unbounded client requests.

On first enablement, **restart Bluetooth or reboot** after rebuilding: NixOS
normally does not restart BlueZ when `main.conf` changes. This briefly disconnects
all Bluetooth peripherals:

```sh
sudo systemctl restart bluetooth.service
```

Then reconnect your AirPods and inspect:

```sh
airpodsd status
bluetoothctl info <AIRPODS_MAC>
sudo journalctl -u airpodsd -b
```

`airpodsd status` shows separate left/right/case readings when available. BlueZ
reports the average of the available earbuds, not a separate case percentage.
Device/firmware support and whether the AirPods are awake affect the readings;
enabling the service does not guarantee every model will supply battery data.

For local development and checks:

```sh
nix build
nix flake check
```

The checks build/test the Rust package, exercise CLI help, and evaluate the
NixOS module. They do not simulate Bluetooth hardware.

## Usage with systemd (without NixOS)
Copy `airpodsd.service` to `~/.config/systemd/user/` or the systemd user service location on your system.

Enable (and start) the service with `systemctl --user enable --now airpodsd`.
