{
  description = "PSBBN Definitive Project env";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        pythonEnv = pkgs.python3.withPackages (
          ps: with ps; [
            lz4
            natsort
            mutagen
            tqdm
            pyicu
            pykakasi
            pillow
            unidecode
            textual
            wcwidth
          ]
        );

        runtimeDeps = with pkgs; [
          pythonEnv
          axel
          imagemagick
          unixtools.xxd
          bc
          rsync
          curl
          wget
          exfatprogs
          ffmpeg
          parted
          fuse2
          bchunk
          e2fsprogs
          ffmpegthumbnailer
          libarchive
          lvm2
          dosfstools
          util-linux
        ];

        psbbn = pkgs.writeShellApplication {
          name = "psbbn";
          runtimeInputs = runtimeDeps;
          # Preserve the script's own error-handling; don't impose set -euo pipefail.
          bashOptions = [ ];
          # The upstream script isn't shellcheck-clean and contains non-ASCII
          # output, which trips writeShellApplication's default check phase.
          checkPhase = "";
          text = builtins.readFile ../../PSBBN-Definitive-Patch.sh;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs =
            runtimeDeps
            ++ (with pkgs; [
              stdenv.cc
              icu
              bash
              pkg-config
              patchelf
              psbbn
            ]);

          shellHook = ''
            ${pkgs.patchelf}/bin/patchelf --set-rpath "${pkgs.fuse2.out}/lib" "./scripts/helper/PFS Fuse.elf"

            rm -rf scripts/venv
            ln -s ${pythonEnv} scripts/venv

            echo -e "\033[1;32m==============================================================\033[0m"
            echo -e "\033[1;36m                PSBBN Definitive Project                      \033[0m"
            echo -e "\033[1;32m==============================================================\033[0m"
            echo ""
            echo -e "Open main menu by executing: \033[1;36mpsbbn\033[0m"
            echo ""
          '';
        };

        apps = {
          psbbn = flake-utils.lib.mkApp { drv = psbbn; };
        };
      }
    );
}
