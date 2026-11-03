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

      # Kernel configEnv on the LLVM toolchain
      llvmConfigEnv =
        pkgs: kernel:
        kernel
        // {
          llvmConfigEnv =
            (kernel.override { stdenv = pkgs.llvmPackages.stdenv; }).configEnv.overrideAttrs
              (prev: {
                nativeBuildInputs = prev.nativeBuildInputs or [ ] ++ [
                  pkgs.llvmPackages.lld
                  pkgs.llvmPackages.llvm
                ];
                env = prev.env or { } // {
                  LLVM = "1";
                };
              });
        };

      # nixpkgs kernels
      kernelsOf =
        pkgs:
        lib.mapAttrs (_: kernel: if lib.isDerivation kernel then llvmConfigEnv pkgs kernel else kernel) (
          pkgs.linuxKernel.kernels
          // {
            inherit (pkgs) linux linux_latest;
          }
        );
    in
    {
      # nix build will output a result that contains source tarball
      packages = forAllSystems (pkgs: {
        default = pkgs.linuxPackages_latest.kernel.src;
      });

      # This provides more direct access to the kernels, making it easier to
      # "build" their src attributes.
      legacyPackages = forAllSystems kernelsOf;

      # Shells of the default kernel
      devShells = forAllSystems (
        pkgs:
        let
          kernel = (kernelsOf pkgs).linux_latest;
        in
        {
          gcc = kernel.configEnv;
          llvm = kernel.llvmConfigEnv;
          default = kernel.llvmConfigEnv;
        }
      );
    };
}
