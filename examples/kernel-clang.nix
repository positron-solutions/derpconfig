{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Stdenv with wrapped LLVM bintools available
  llvmKernelStdenv = pkgs.stdenvAdapters.overrideInStdenv pkgs.llvmPackages.stdenv [
    pkgs.llvmPackages.bintools
  ];

  kernel = pkgs.linuxKernel.kernels.linux_7_2.override {
    name = "linux-kernel-clang";
    modDirVersion = "7.2.0-Clang";
    extraMakeFlags = [
      "KCFLAGS+=-march=znver2"
      "KCFLAGS+=-Wno-unused-command-line-argument"
      "CC=${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
      "AR=${pkgs.llvm}/bin/llvm-ar"
      "NM=${pkgs.llvm}/bin/llvm-nm"
      "LD=${pkgs.lld}/bin/ld.lld"
      "LLVM=1"
      "HOSTLDFLAGS=-Wl,-rpath,${lib.getLib pkgs.openssl}/lib -Wl,-rpath,${lib.getLib pkgs.elfutils}/lib"

      # Verbose commands and extra warnings, higher levels available
      # "V=1"
      # "W=1"
    ];

    stdenv = llvmKernelStdenv;

    # Config generation failing usually corresponds to your config being edited
    # in the output due to the incompatible options and therefore also failing.
    # ignoreConfigErrors = true;

    # Start with an all-no config.  It is slightly easier to pull together
    # enough options to get this running than to whittle down the defaults.
    # However, it is still a lot and you may miss some that are more important
    # than what you gain by starting from a clean slate.
    # defconfig = "tinyconfig LLVM=1 ARCH=x86_64";

    # Be sure to always use defaults compatible with the intended host
    defconfig = "defconfig LLVM=1 ARCH=x86_64";

    structuredExtraConfig = with lib.kernel; {
      CC_IS_CLANG = lib.mkForce yes;
      LTO = lib.mkForce yes;
      LTO_CLANG = lib.mkForce yes;
      LTO_CLANG_THIN = lib.mkForce yes;
    };
  };

  zfsAttr = pkgs.zfs.kernelModuleAttribute;

  linuxPackages_custom = (pkgs.linuxPackagesFor kernel).extend (
    final: prev: {
      ${zfsAttr} = prev.${zfsAttr}.overrideAttrs (old: {
        configureFlags =
          lib.filter (
            flag:
            !lib.any (prefix: lib.hasPrefix prefix flag) [
              "KERNEL_KCFLAGS+="
              "KERNEL_HOSTLDFLAGS="
            ]
          ) old.configureFlags
          ++ [ "KERNEL_KCFLAGS=-march=znver2" ];
      });
    }
  );

in
{
  # Customize the patch set in use for either adding to a tinyconfig or
  # subtracting from defconfig
  boot.kernelPatches =
    with (import ./patches.nix { inherit lib; });
    subtract
    ++ base
    ++ [
      custom
      g14
    ];
  # boot.kernelPatches = with (import ./patches.nix {inherit lib;});
  #   addition ++ base ++ [ custom g14 ];

  boot.kernelPackages = linuxPackages_custom;

  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "615.71.09";

    sha256_64bit = "sha256-zc7tIrvrYSSNGm3qvCWWZz46ZQFpjucayNL9wo87cP4=";
    sha256_aarch64 = "sha256-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=";
    openSha256 = "sha256-3gByMYIwFzRaLdDG+roCEOuKRRJDrljG9AlLnRZTirM=";
    settingsSha256 = "sha256-LK1LU8mDkM/XVRKPBtuOZh9nIP/lGFLAJnmasEX8jhg=";
    persistencedSha256 = "sha256-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee=";

    patchesOpen = [
      (pkgs.fetchpatch {
        url = "https://patch-diff.githubusercontent.com/raw/NVIDIA/open-gpu-kernel-modules/pull/1330.patch";
        hash = "sha256-itS4dDWwyyJiXphP44ow9F+mPe98RPJCeVVhfMOkBYo=";
      })
    ];
  };
}
