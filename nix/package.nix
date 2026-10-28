{ lib, rustPlatform, pkg-config, dbus, bluez }:

rustPlatform.buildRustPackage {
  pname = "airpodsd";
  version = "0.1.0";

  # Documentation/module changes should not rebuild the Rust dependency graph.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [ ../Cargo.toml ../Cargo.lock ../src ];
  };
  cargoLock.lockFile = ../Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus bluez ];

  meta = {
    description = "Expose AirPods battery information through BlueZ";
    homepage = "https://github.com/joaomsa/airpodsd";
    mainProgram = "airpodsd";
    platforms = lib.platforms.linux;
  };
}
