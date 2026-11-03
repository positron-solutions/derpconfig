{
  description = "Devshells for kernel configuration.  Kernel source hacking conveniences.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    inputs:
    with inputs;
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # nix build will output a result that contains source tarball
      packages = forAllSystems (pkgs: {
        default = pkgs.linuxPackages_latest.kernel.src;
      });

      # nix develop will obtain tools that can be used to configure a kernel.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bison # needed by kernel build system
            flex # needed by kernel build system
            gcc # compiler
            git # handy to have
            glibc.dev
            gnumake
            makeWrapper # for wrapping commands
            ncurses
            pkg-config
            pkgs.makeWrapper

            # Only needed for LLVM builds
            llvmPackages.clang
            lld
            llvm
          ];

          # Disable if you are not doing LVM builds
          stdenv = pkgs.llvmPackages.stdenv;
          LLVM = 1;

          shellHook = ''
            echo "Kernel devshell ready!"
               echo "Run: make defconfig or make menuconfig inside kernel source"
          '';
        };
      });
    };
}
