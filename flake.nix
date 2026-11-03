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
      devShells = forAllSystems (
        pkgs:
        let
          commonInputs = with pkgs; [
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
          ];

          shellHook = ''
            echo "Kernel devshell ready!"
            echo "Run: make defconfig or make menuconfig inside kernel source"
          '';

          # GCC toolchain
          gccShell = pkgs.mkShell {
            buildInputs = commonInputs;
            inherit shellHook;
          };

          # LLVM toolchain
          llvmShell = pkgs.mkShell.override { stdenv = pkgs.llvmPackages.stdenv; } {
            buildInputs =
              commonInputs
              ++ (with pkgs; [
                llvmPackages.clang
                lld
                llvm
              ]);
            LLVM = 1;
            inherit shellHook;
          };
        in
        {
          gcc = gccShell;
          llvm = llvmShell;
          default = llvmShell;
        }
      );
    };
}
