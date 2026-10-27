{ config, pkgs, lib, ...}:

let 
  # Stdenv with a few more LLVM tools available
  llvmKernelStdenv =
    pkgs.stdenvAdapters.overrideInStdenv pkgs.llvmPackages.stdenv [
      pkgs.llvm
      pkgs.lld
    ];

  kernel = pkgs.linuxKernel.kernels.linux_7_3.override {
    name = "linux-kernel-clang";
    modDirVersion = "7.3.0-Clang";
    extraMakeFlags = [
      "KCFLAGS+=-O2"
      "KCFLAGS+=-mtune=znver2"
      "KCFLAGS+=-march=znver2"
      "KCFLAGS+=-Wno-unused-command-line-argument"
      "CC=${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
      "AR=${pkgs.llvm}/bin/llvm-ar"
      "NM=${pkgs.llvm}/bin/llvm-nm"
      "LD=${pkgs.lld}/bin/ld.lld"
      "LLVM=1"
      "HOSTLDFLAGS=-Wl,-rpath,${lib.getLib pkgs.openssl}/lib -Wl,-rpath,${lib.getLib pkgs.elfutils}/lib"

      # For debugging builds.  Higher numbers available.
      # "V=1"
      # "W=1"
    ];

    stdenv = llvmKernelStdenv;

    # Config generation failing usually corresponds to your config begin edited
    # in the output due to the incompatible options and thzerefore also failing.
    # ignoreConfigErrors = true;

    # Start with an all-no config.  It is slightly easiler to pull together
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

  # What may need to actually happen here is swapping kernel dependents back to
  # seeing the normal GCC toolchain.  It is likely that these programs rely on
  # the headers and ABI compatibility but not which compiler was used.  The
  # kernel stdenv is used to build the linuxPackagesFor.  We should just change
  # that back to GCC for dependents to try this theory out.  In the meantime,
  # this overrides the individual packages I need working now.
  linuxPackages_custom =  (pkgs.linuxPackagesFor kernel).extend (kfinal: kprev: {
    # Perf depends on systemtap's stapBuild derivation, which fails possibly due
    # to use of Clang
    # systemtap = kprev.systemtap.overrideAttrs (old: {
    #   stapBuild = old.stapBuild.overrideAttrs (oldStap: {
    #     configureFlags = (oldStap.configureFlags or []) ++ [ "--disable-Werror" ];
    #   });
    # });

    # TODO this builds.  It runs.  It works.  But it is suspect to be building
    # perf with gcc when the kernel is built with Clang?
    # perf = kprev.perf.overrideAttrs (old: {
    #   makeFlags = (old.makeFlags or []) ++ [
    #     # Just build it with GCC..
    #     "CC=${pkgs.stdenv.cc}/bin/gcc"
    #   ];
    # });
  });

in {
  # Customize the patch set in use for either adding to a tinyconfig or
  # subtracting from defconfig
  boot.kernelPatches = with (import ./patches.nix {inherit lib;});
    subtract ++ base ++ [ custom g14 ];
  # boot.kernelPatches = with (import ./patches.nix {inherit lib;});
  #   addition ++ base ++ [ custom g14 ];

  boot.kernelPackages = linuxPackages_custom;

  # This override could be a lot simpler with some upstream changes and the
  # manual inclusion of the kernel module farther below would be a lot simpler.
  hardware.nvidia.package = (config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "595.112.07";

    sha256_64bit = "sha256-Gjjs1Tii2mIypzMBhAY69Z6fyUbJCMylVb0HkJhIufA=";
    sha256_aarch64 = "sha256-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=";
    openSha256 = "sha256-hECHfguzwduEfPo5pCDjWE/MjtRDhINVr4b1awFdP44=";
    settingsSha256 = "sha256-2bWSou/9J3EojhSRXBol/+yGGu2XZ6EuCptb5qXHM14=";
    persistencedSha256 = "sha256-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee=";
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
}
