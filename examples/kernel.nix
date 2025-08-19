{ config, pkgs, pkgsUnstable, lib, ...}:

let 
  # Stdenv with a few more LLVM tools available
  llvmKernelStdenv =
    pkgs.stdenvAdapters.overrideInStdenv pkgs.llvmPackages.stdenv [
      pkgs.llvm
      pkgs.lld
    ];

  kernelOverlay = (final: prev: {
    linuxPackages_latest = prev.linuxPackages_latest.extend (kfinal: kprev: {
      kernel = (kprev.kernel.override {
        modDirVersion = "6.16.0-Clang";
        # modDirVersion = "6.16.0-GCC";
        extraMakeFlags = [
          # Gcc flags.
          # "KCFLAGS+=-O3"
          # "KCFLAGS+=-march=znver2"
          # "KCLAGS+=-mtune=znver2"

          # Clang/llvm flags
          "KCFLAGS+=-O3"
          "KCFLAGS+=-mtune=znver2"
          "KCFLAGS+=-march=znver2"
          "KCFLAGS+=-Wno-unused-command-line-argument"
          "CC=${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
          "AR=${pkgs.llvm}/bin/llvm-ar"
          "NM=${pkgs.llvm}/bin/llvm-nm"
          "LD=${pkgs.lld}/bin/ld.lld"
          "LLVM=1"

          # For debugging builds.  Higher numbers available.
          # "KCFLAGS+=V=1"
          # "KCFLAGS+=W=1"
        ];

        stdenv = llvmKernelStdenv;

        # Config generation failing usually corresponds to your config begin edited
        # in the output due to the incompatible options and therefore also failing.
        # ignoreConfigErrors = true;
       
        # Start with an all-no config.  It is slightly easiler to pull together
        # enough options to get this running than to whittle down the defaults.  
        # However, it is still a lot and you may miss some that are more important
        # than what you gain by starting from a clean slate.  
        # defconfig = "allnoconfig LLVM=1 ARCH=x86_64";

        # Be sure to always use defaults compatible with the intended host
        defconfig = "defconfig LLVM=1 ARCH=x86_64";
        
        # GCC
        # defconfig = "defconfig ARCH=x86_64";
      });
    });
  });

in {
  # Customize the patch set in use for either adding to a allnoconfig or
  # subtracting from defconfig
  boot.kernelPatches = (import ./patches.nix {inherit lib;}).subtract;

  # Just use whatever latest Kernel is out?
  # boot.kernelPackages = nixpkgs-unstable.linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_6_5;


  nixpkgs.overlays = [ kernelOverlay ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.nvidia.package = (config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "580.76.05";

    sha256_64bit = "sha256-IZvmNrYJMbAhsujB4O/4hzY8cx+KlAyqh7zAVNBdl/0=";
    sha256_aarch64 = "sha256-NL2DswzVWQQMVM092NmfImqKbTk9VRgLL8xf4QEvGAQ=";
    openSha256 = "sha256-xEPJ9nskN1kISnSbfBigVaO6Mw03wyHebqQOQmUg/eQ=";
    settingsSha256 = "sha256-ll7HD7dVPHKUyp5+zvLeNqAb6hCpxfwuSyi+SAXapoQ=";
    persistencedSha256 = "sha256-bs3bUi8LgBu05uTzpn2ugcNYgR5rzWEPaTlgm0TIpHY=";
  }).overrideAttrs (old: {
    # TODO if there is a way to somehow override this more deeply so that it may
    # occur within an overlay, let be known by whoever reads this and understands
    # this issue.
    passthru = old.passthru // {
      open = old.passthru.open.overrideAttrs (o: {
        makeFlags = (o.makeFlags or []) ++ [
          "CC=${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
          "KCFLAGS+=-isystem ${pkgs.glibc.dev}/include"
          "KCFLAGS+=-Wno-implicit-function-declaration"
        ];
      });
    };
  });

  # It is a great wonder why this would be necessary.  We have
  # derived our nvidia from the kernelPackages, and so our
  # extension of passthru with an augmented makeFlags should..
  # just work.  For whatever reason, instead the nvidia module
  # is not installed with other kernel modules unless we
  # explicitly add the package back in.
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11/open.nix#L29-L40
  boot.extraModulePackages = [ config.hardware.nvidia.package ];
  
  # .:: Tiny boot partion options included below
  #
  # When setting initrd options this way, the correct ones to boot
  # must be included.  Result is about 22MB for one kernel and initrd.
  # which makes it easy to fit on my anemically chosen boot partition.
  # 
  # Note, 19 is the highest, but was selected by these settings
  boot.initrd.compressorArgs = ["-22" "-T0" "--long" "--ultra"];
  boot.loader.systemd-boot.configurationLimit = 1;
  boot.initrd.includeDefaultModules = false;

  boot.initrd.luks.cryptoModules = [
    "aes"
    "xts"
    "sha256_generic"
  ];

  boot.initrd.availableKernelModules = lib.mkForce [
    "aesni_intel"    # Hardware AES acceleration (Intel) — on AMD, kernel uses analogous driver
    "cryptd"         # Crypto processing helper
    "dm_mod"         # Device mapper for LVM
    "dm_crypt"       # LUKS encryption
    "ext4"           # Root filesystem driver
    "nvme"           # NVMe storage
    "usbhid"         # USB keyboard
    "xhci_pci"       # USB 3 controller (handles most modern boards)
  ];
}
