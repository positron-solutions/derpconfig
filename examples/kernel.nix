{ config, pkgs, pkgsUnstable, lib, ...}:

let 
  # Stdenv with a few more LLVM tools available
  llvmKernelStdenv =
    pkgs.stdenvAdapters.overrideInStdenv pkgs.llvmPackages.stdenv [
      pkgs.llvm
      pkgs.lld
    ];

  kernel = pkgsUnstable.linuxPackagesFor
    (pkgsUnstable.linuxKernel.kernels.linux_latest.override {
    extraMakeFlags = [
      # Gcc flags.
      # "KCFLAGS+=-O3"
      # "KCFLAGS+=-march=znver2"
      # "KCFLAGS+=-mtune=znver2"

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
    # defconfig = "ARCH=x86_64 allnoconfig LLVM=1";
  });

in {
  # Customize the patch set in use for either adding to a allnoconfig or
  # subtracing from defconfig
  boot.kernelPatches = (import ./patches.nix {inherit lib;}).remove-from-defconfig;

  # Just use whatever latest Kernel is out?
  # boot.kernelPackages = nixpkgs-unstable.linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_6_5;
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # Nah, build kernels from source!
  boot.kernelPackages = kernel;

  # In order to get the Nvidia kernel modules included correctly, it was 
  # necessary to get the nvidia driver through the kernel we let-bound 
  # earlier.  Using boot.kernelPackages did NOT work.
  hardware.nvidia.package = kernel.nvidiaPackages.beta.overrideAttrs (old: {
    kernelModuleMakeFlags = [
      # The clange here will not by default match the one used during the kernel build
      "IGNORE_CC_MISMATCH=1"
    ];

    # Override the kernel module to provide a clang and knowledge of glibc
    passthru = old.passthru // {
      open = old.passthru.open.overrideAttrs (oldOpen: {
         makeFlags = oldOpen.makeFlags or [] ++ [
           # Provide an unwrapped clang just for better behavior
           "CC=${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
           "KCFLAGS+=-isystem ${pkgs.glibc.dev}/include"
           "KCFLAGS+=-Wno-implicit-function-declaration"
         ];
       });
     };
  });

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
