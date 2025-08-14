{
  description = "Kernel devshell for Kernel configurationg";

  inputs = {
    pins.url = "github:positron-solutions/pins";
    nixpkgs.follows = "pins/nixpkgs";
  };

  outputs = inputs: with inputs;
    let
      # update as needed
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      # Select another version here or add packages for flexibility
      linuxKernel = pkgs.linuxPackages_latest.kernel;
    in {
      # nix build will output a result that contains source tarball
      packages.${system}.default = pkgs.linuxPackages_latest.kernel.src;

      # nix develop will obtain tools that can be used to configure a kernel.
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          bison          # needed by kernel build system
          flex           # needed by kernel build system
          gcc            # compiler
          git            # handy to have
          glibc.dev
          gnumake
          makeWrapper    # for wrapping commands
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
    };
}
