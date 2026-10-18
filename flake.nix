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
            echo "kanaru dev shell — $(flutter --version 2>/dev/null | head -1)" >&2
          '';
        };
      });
}
