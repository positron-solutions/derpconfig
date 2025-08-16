# DerpConfig

Small setup for iterating on NixOS kernel configs.  People do this to obtain
smaller and faster kernels.  Smaller kernels build faster, especially on faster
kernels.

### Motivation

| Configuration                                | AES-XTS 256 Performance (MB/s) |
|----------------------------------------------|--------------------------------|
| Stock kernel                                 | ~1800 MB/s                     |
| Tuned (clang LTO, CPU tuned, no mitigations) | ~3500 MB/s                     |

Tested with `crytosetup benchmark`. Other critical OS behaviors like zramswap
can really benefit and give applications more room to breathe.  The target
application, building containers with Rust and Nix, is still under
investigation, but early indications are reduction in a well-known process from
0.27s to 0.2s without compiling that specific program specially (yet).

**Workflows** and **ease of use** were also under study.  Some pain points
within the NixOS nixpkgs modules were identified.  Work here builds on top of
`structuredExtraConfig` rather than using custom configs that won't react to the
NixOS module system.

### Also Covered

- [examples/patches.nix](examples/patches.nix) demonstrates what
  mass-deactivation looks like. (the alternative is setting `defconfig` to
  `"allnoconfig"`  and adding from scratch along with NixOS defaults).
- [examples/kernel.nix](examples/kernel.nix) contains an example kernel
  configuration with both LLVM and GCC variants in the comments.  **The nvidia
  kernel module must be compiled from your kernel derivation** as shown or
  problems are easy to run into.
- The kernel module also contains an example of reducing the initrd and
  maximally compressing the kernel (requires almost no time to save a little
  disk space).

### Not a Library

**This repo is more demonstrative than intended for blind consumption**;

ℹ️ The flake contains versions and pins that will affect your results and should
be customized or at least checked for freshness by the user.

### Maintenance

Using Kernel customizations will require re-building every time you update
nixpkgs or change the kernel's configuration.  If you build without all drivers,
you will need to recompile if one of those drivers turns out to be necessary.

## Using the Flake Shell

1. Update the flake.nix to point nixpkgs to the rev you intend to upgrade to
1. `nix build` to obtain a `result` that points to the linux src tarball.
1. `tar -xvf result` to obtain linux-6.16.0 etc
1. `direnv allow` or `nix develop` to obtain tools necessary for the
   configuration make targets
1. Inside the linux src, run `make menuconfig` and you should see a config.  You
   can modify this, diff and transform it to obtain patches as desired.

## Hacking on Your Config

This first approach is useful for exploring and tuning your starting point and
also the additive and substractive workflows described farther below.

1. `zcat /proc/config.gz | tee old > .config` to obtain your running config
    - This is controlled by `IKCONFIG` and `IKCONFIG_PROC`, which are on by
      default and likely shouldn't be turned off
1. `yes "" | make oldconfig` to pick up any new options that were not set at all
1. `make menuconfig` and tool around
1. Save the config.  Extract the lines of diff so that we can feed them into ~~a
   carefully written script~~ FauxpenAI
   ```bash
    diff --changed-group-format='%>' --unchanged-group-format='' old .config
   ```
1. Create a kernel patch with `structuredExtraConfig` that can be merged on top
   of options set by NixOS in [the
   defaults](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/common-config.nix).
   This must be added to `boot.kernelPatches`.
   ```ChatGPT
   Dear Sam, please convert the following lines of Linux kernel config to NixOS
   extraStructured config within a kernel patch for boot.kernelPatches.  Use
   lib.kernel to coerce choices to the correct format.  Use mkForce when
   disabling.
   ```
1. `nixos-rebuild switch` and it takes about an hour on a five year-old laptop
   unless you have significantly reduced the drivers and things.  
1. 💡 **The first runs will likely not be successful**!  You must fix up
   sympathetic options as described below.   

### Fixing Up Sympathetic Options

During rebuild, NixOS runs a script that will identify unused options.  That
were disabled as a result of the ones you selected.  Just add them to the pile
2-3 times and you will have reached a stable fixed point.  See the
`localmod-fallout` patch in [examples/patches.nix](examples/patches.nix).
**This is one of the biggest drawbacks of our current kernel configuration
infrastructure.**  Pay attention to `pkgs.kernel` and use of `lib.mkForce` and
`mkDefault`.  💡 The `unset` option is really helpful when you need to turn off
something that NixOS is trying to turn on!

### Tips 💡

There are more make targets **and scripts** that support options and may
streamline some workflows based on combining several configs.  It is good for us
to know these to consider some improvements to generation of NixOS hardware
configs, which can be done whenever running a fat kernel that will have
everything in `lsmod`.  For example, loading alternate configs to see what they
activate:

```
make KCONFIG_CONFIG=./reduced menuconfig
```

Be sure to use `LLVM=1` on **all** commands when doing work with LLVM.
The outputs will default to GCC selections if you do not.

## Contribution Ideas

- More pre-made `extraStructuredConfig` to reduce the absurd amount of old
  drivers in defconfig.  We could use sets of things for various purposes and
  accurate usage of `mkDefault` and `mkForce`
- Patches for starting from `allnoconfig` and workflows to obtain the necessary
  `localmodconfig` to have full hardware support
- NixOS modules that encompass the choices better
- Upstream patches to nixpkgs to enable more flexible generic Linux kernel
- Many kernel modules are only likely to be used in rare cases and would
  actually be better of compiled with `-Oz` or even compiled on demand (see
  below)
- Injecting some uname info, such as with `modDirVersion`

## Future Directions

This work is a preliminary exploration of several ideas:

- On-demand device -> driver mapping and on-demand kernel module recompiling so
  that NixOS can ship a lean kernel that retains full device support.  This would
  make it much less painless to use `-mtune` and `-march` flags as well as
  optional mitigations and other tradeoffs.
- Provide the Linux kernel with a recursive merging DAG style configuration that
  can expose high-level and low-level options simultaneously and can expose
  options for high-level conflicts as well.  Such an interface would be more
  useful for automation in NixOS.
- On-demand support for kernel level anti-cheats and other boot mechanisms that
  some 3rd party publishers rely on while also exploring better solutions and
  bringing the users and publishers to the same table.
- On-demand Nvidia driver fixups and other automations for these finicky derivations
  that often require switching versions and are extremely easy to mess up the
  expressions for.

## Shameless Self-Promotion 💸

This work was produced in the course of building
[PrizeForge.com](prizeforge.com).  You can consider it as a tip jar, but it will
be much more.  It is a community tip char where we users will drive development
by showing open source authors, maintainers, and contributors, what we want them
to work on.  In the course of deciding what to work on, users will provide each
other support.  Good support comes from people who know what needs to be done.
When good users who give support are able to decide what to work on, 

Give me a monetary tip to accelerate its development.  As soon as it is
underway, the world will move faster with more open source, more open IP in
general, and less stupid competition.
