{ config, pkgs, lib, ...}:

let 
  kernelOverlay = (final: prev: {
    linuxPackages_latest = prev.linuxPackages_latest.extend (kfinal: kprev: {
      kernel = (kprev.kernel.override {
        name = "linux-kernel-gcc";
        modDirVersion = "6.16.0-gcc-O3";
        extraMakeFlags = [
          # Gcc flags.
          # These are CPU-dependent and allow slightly better ordering of things
          # to suit the particular CPU's tendencies.
          "KCFLAGS+=-march=znver2"
          "KCLAGS+=-mtune=znver2"
          # This can result in slightly larger binaries or more aggressive
          # optimization or bugs or all three, but you're a cowboy 🤠.  GCC does
          # support PGO which would get more out of these settings.  There is
          # also a LTO patch floating around but mainline does not seem to
          # support it yet.
          "KCFLAGS+=-O3"

          # For debugging builds.  Higher numbers available.
          # "KCFLAGS+=V=1"
          # "KCFLAGS+=W=1"
        ];

        # Config generation failing usually corresponds to your config begin edited
        # in the output due to the incompatible options and therefore also failing.
        # ignoreConfigErrors = true;
       
        # Start with an all-no config.  It is slightly easiler to pull together
        # enough options to get this running than to whittle down the defaults.  
        # However, it is still a lot and you may miss some that are more important
        # than what you gain by starting from a clean slate.  
        # defconfig = "tinyconfig LLVM=1 ARCH=x86_64";

        # This is the default but kept as a reminder to check generate-config.pl
        # and understand that there is a base config that has default options
        # added on top from common-config.nix
        defconfig = "defconfig ARCH=x86_64";
      });
    });
  });

in {
  # Customize the patch set in use for either adding to a tinyconfig or
  # subtracting from defconfig
  boot.kernelPatches = with (import ./patches.nix {inherit lib;});
    subtract ++ base;
  # boot.kernelPatches = with (import ./patches.nix {inherit lib;});
  #   addition ++ base;

  nixpkgs.overlays = [ kernelOverlay ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Note, Nvidida is a little bit simpler in this version since we don't need to
  # override the open source module or be sure the kernel module is installed.
  hardware.nvidia.package = (config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "580.76.05";

    sha256_64bit = "sha256-IZvmNrYJMbAhsujB4O/4hzY8cx+KlAyqh7zAVNBdl/0=";
    sha256_aarch64 = "sha256-NL2DswzVWQQMVM092NmfImqKbTk9VRgLL8xf4QEvGAQ=";
    openSha256 = "sha256-xEPJ9nskN1kISnSbfBigVaO6Mw03wyHebqQOQmUg/eQ=";
    settingsSha256 = "sha256-ll7HD7dVPHKUyp5+zvLeNqAb6hCpxfwuSyi+SAXapoQ=";
    persistencedSha256 = "sha256-bs3bUi8LgBu05uTzpn2ugcNYgR5rzWEPaTlgm0TIpHY=";
  });
}
