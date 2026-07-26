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
        psbbn = pkgs.writeScriptBin "psbbn" ''
          #!${pkgs.bash}/bin/bash
          ${builtins.concatStringsSep "\n" (
            builtins.tail (pkgs.lib.splitString "\n" (builtins.readFile ../../PSBBN-Definitive-Patch.sh))
          )}
        '';

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
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            stdenv.cc
            icu
            bash
            pythonEnv
            axel
            imagemagick
            unixtools.xxd
            bc
            rsync
            curl
            zip
            unzip
            wget
            exfatprogs
            ffmpeg
            parted
            fuse2
            bchunk
            e2fsprogs
            pkg-config
            patchelf
            ffmpegthumbnailer
            pkgsi686Linux.glibc
            unrar-free
            lvm2
            dosfstools
            util-linux
            psbbn
          ];

          shellHook = ''
            ${pkgs.patchelf}/bin/patchelf --set-rpath "${pkgs.fuse2.out}/lib" "./scripts/helper/PFS Fuse.elf"

            # patch ps2str to use 32-bit glibc from Nix
            ${pkgs.patchelf}/bin/patchelf --set-interpreter ${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2 ./scripts/helper/ps2str

            mkdir -p scripts/venv/
            ln -sfn ${pythonEnv}/* ./scripts/venv/

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
