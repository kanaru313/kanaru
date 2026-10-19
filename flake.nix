{
  description = "Kanaru — music player (Flutter + Material 3)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Native libraries the Linux desktop build links against.
        nativeLibs = with pkgs; [
          # Flutter Linux embedder (GTK)
          gtk3
          glib
          pcre2
          util-linux
          libselinux
          libsepol
          libthai
          libdatrie
          libxkbcommon
          libepoxy
          libxdmcp
          libxtst
          lerc
          libdeflate
          xz
          # media_kit (libmpv)
          mpv-unwrapped
          # flutter_secure_storage
          libsecret
          jsoncpp
          # drift
          sqlite
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            flutter

            # Linux desktop toolchain
            clang
            cmake
            ninja
            pkg-config

            # Rust (tag reading via lofty + flutter_rust_bridge)
            rustc
            cargo
            rustfmt
            clippy
            rust-analyzer
            flutter_rust_bridge_codegen
            # flutter_rust_bridge_codegen shells out to `cargo expand`
            # (run it with RUSTC_BOOTSTRAP=1 on the stable toolchain).
            cargo-expand
            # Cargokit (flutter_rust_bridge's build glue) always calls rustup.
            # Nix gives one stable toolchain, so answer the three calls it
            # makes for that one.
            (writeShellScriptBin "rustup" ''
              case "$1" in
                toolchain) echo "stable-${stdenv.hostPlatform.rust.rustcTarget} (default)" ;;
                target) echo "${stdenv.hostPlatform.rust.rustcTarget}" ;;
                run) shift 2; exec "$@" ;;
                *) echo "rustup shim: unsupported: $*" >&2; exit 1 ;;
              esac
            '')

            # Poking the MPRIS service by hand
            playerctl

            # Packaging
            appimage-run
            flatpak-builder
          ] ++ nativeLibs;

          # ffigen / flutter_rust_bridge need libclang
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

          # Let `flutter run` find shared libs at runtime
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeLibs;

          shellHook = ''
            export PATH="$HOME/.pub-cache/bin:$PATH"
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
            echo "kanaru dev shell — $(flutter --version 2>/dev/null | head -1)" >&2
          '';
        };
      });
}
