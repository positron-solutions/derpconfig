# DerpConfig

Small setup for iterating on NixOS kernel configs.  People do this to obtain
smaller and faster kernels.

### Motivation

| Configuration                                | AES-XTS 256 Performance (MB/s) |
|----------------------------------------------|--------------------------------|
| Stock kernel                                 | ~2200 MB/s                     |
| Tuned (clang LTO, CPU tuned, no mitigations) | ~3500 MB/s                     |

Some core kernel tasks are a lot faster with some tuning.  Tested with
`crytosetup benchmark`.  Zswapping under load is another likely beneficiary.

<details>
<summary>caveats</summary>

- The kernel is only a large fraction of work when your system is
  thrashing, booting, or programs are starting and doing tons of syscalls.  A 50%
  boost for the kernel might be 0.3% for the application.

- Latency sensitive tasks likely benefit from scheduling more than straight
  line kernel speed.

- Tasks that thrash will typically bottleneck on disk swapping, and tools like
  zram-swap will have a bigger impact (but zram-swap itself will benefit
  probably!)

Building a Rust application from `cargo clean` saw no measurable change.
However, the cache-hot restart went from 0.26s to 0.19s.  Starting a process
that has to verify that many files are unchanged is almost entirely OS bound.
</details>

**Workflows** and **ease of use** are also under study.  Some **[pain
points](#early-takeaways) within the NixOS nixpkgs modules were identified.**
Work here builds on top of `structuredExtraConfig` rather than using custom
.config files that won't react to the NixOS module system.

Since I have LLVM working, one possible next step is supplying FDO/PLO (Feedback
and Post-Link Optimization) input to the derivation, possibly for automating
binary substitution in nixd.

### Example Files

- [examples/patches.nix](examples/patches.nix) demonstrates what
  mass-deactivation looks like. (the alternative is setting `defconfig` to
  `"tinyconfig"`  and adding from scratch along with NixOS defaults).
- [examples/kernel-llvm.nix](examples/kernel-llvm.nix) contains an example
  kernel configuration building with LLVM and clang.  **The nvidia kernel module
  must be derived from your kernel** as shown **and included into your kernel
  modules** or problems are easy to run into.
- [examples/tinyboot.nix](examples/tinyboot.nix) shows how to deal with a
  relatively small boot partition, reducing the initrd and maximally compressing
  the kernel (requires almost no time to save a little disk space).

### Not a Library

**This repo is more exploratory and demonstrative than intended for blind
consumption**.  Run your own scripts.  🙅 Kernel versions add options.  NixOS
modules change See `make oldconfig`.

### Maintenance

Using Kernel customizations **will require re-building** every time you update
nixpkgs or change the kernel's configuration.  If you build without all drivers,
you will need to recompile if one of those drivers turns out to be necessary.

## Get Started!

1. Update the flake.nix to point nixpkgs to the rev you intend to upgrade to
1. `nix build` to obtain a `result` that points to the linux src tarball.
1. `tar -xvf result` to obtain linux-6.16.0 etc
1. `direnv allow` or `nix develop` to obtain tools necessary for the
   configuration make targets
1. Inside the linux src, run `make menuconfig` and you should see a config.  You
   can modify this, diff and transform it to obtain patches as desired.

### Hacking on Your Existing Config

This first approach is useful for exploring and tuning your starting point so
you can get familiar.

1. `zcat /proc/config.gz | tee old > .config` to obtain your running config
    - The existence of that file is controlled by `IKCONFIG` and
      `IKCONFIG_PROC`, which are on by default and likely shouldn't be turned
      off
1. `yes "" | make oldconfig` to pick up any new options that were not set at all
1. `make menuconfig` and tool around
1. Save the config as "new" etc.  Extract the lines of diff:
   ```bash
   ./scripts/diffconfig OLD NEW
   ```
1. Feed diff lines into ~~a carefully written script~~ FauxpenAI
   ```ChatGPT
   .:: a modern regex:
   
   Dear Sam, please convert the following lines of Linux kernel config to NixOS
   extraStructured config within a kernel patch for boot.kernelPatches.  Use
   lib.kernel to coerce choices to the correct format.  Use mkForce when
   unsetting.
   ```   
1. Create a kernel patch with `structuredExtraConfig` that can be merged on top
   of options set by NixOS in [the
   defaults](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/common-config.nix).
   This must be added to `boot.kernelPatches`.
1. `nixos-rebuild switch` **The first runs will likely not be successful**!  You must fix up
   **dependent options** as described below.  This takes about 2-3min per run.
1. Once config passes, it takes 2-3 hours to build (five year-old laptop) unless
   you have significantly reduced the drivers and things.

### Fixing Up Dependent Options

During rebuild, NixOS runs a [perl
script](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/generate-config.pl)
that will identify unused options.  That
were disabled as a result of the ones you selected.  

<details>
<summar>build log output</summary>
```
linux-config> error: unused option: REGULATOR_MC13XXX_CORE
linux-config> error: unused option: REGULATOR_ROHM
linux-config> error: unused option: REGULATOR_TPS68470
linux-config> warning: unused option: REISERFS_FS_SECURITY
linux-config> error: option not set correctly: RTLWIFI (wanted 'n', got 'm')
linux-config> error: option not set correctly: RTLWIFI_PCI (wanted 'n', got 'm')
linux-config> error: option not set correctly: SCSI_COMMON (wanted 'n', got 'm')
linux-config> error: unused option: TINYDRM
linux-config> error: unused option: TORTURE_TEST
linux-config> error: unused option: USB_SERIAL_CONSOLE
linux-config> error: unused option: USB_SERIAL_GENERIC
```
</details>

- unused errors: recommend commenting the change
- "wanted 'n', got 'm'" style errors: try forcing unset or no before commenting

Just add them to a "fallout" list 2-3 times and you will have reached a stable
fixed point.  Search patches for "fallout" to see what I mean
[examples/patches.nix](examples/patches.nix).

**This is one of the biggest drawbacks of our current kernel configuration
infrastructure.**  Pay attention to `pkgs.kernel` and use of `lib.mkForce` and
`mkDefault`.  The `unset` option is really helpful when you need to turn off
something that NixOS is trying to turn on!

## Tips 💡

Firstly, there is an **ongoing rename** from `extraStructuredConfig` (current)
to `structuredExtraConfig` (new).  Watch out for this because there's almost no
feedback depending on which commit you're on.

### Extra Make Targets & Variables

There are more make targets **and scripts** that support options and may
streamline some workflows based on combining several configs.

### Print Build Logs

This helps debugging config problems since the output from the failure is right there.

```
nixos-rebuild boot --print-build-logs
```

### Marking and Identifying Your Kernels

Use `cat /proc/version` to see some info about your current kernel.  It always
includes the compiler info.  Set the `modVersion` to have extra info there.
```
Linux version 6.16.0 (nixbld@localhost) (clang version 19.1.7, LLD 19.1.7)
#1-NixOS SMP PREEMPT_DYNAMIC Sun Jul 27 21:26:38 UTC 2025
```

## Building Smaller Kernels

We want a small config so we can rebuild cheaply.  A full fat kernel build can
take several hours.  Currently I'm down to about 45min for a thin-LTO LLVM
build.  There are still at least 1k unused drivers building.

We must know:

- which drivers and capabilities are absolutely necessary on a given piece of hardware?
- what is NixOS enabling to be safe that we can disable?

### Identifying Options Required by Hardware

With the present tools.  This seems difficult.

We are interested in settings that are:

1. not part of NixOS because those will be enabled anyway
2. not part of our defconfig, which may be tinyconfig, aka "the bare minimum to boot"
3. not already activated from activating a dependent

The **error** output from the streamline script (and how the perl script obtains
it) look valuable.

```bash
  make tinyconfig ARCH=x86_64 LLVM=1
  make localmodconfig # prints error output about things that were not enabled
```

**This must be done from a fat config** with all modules for intended
hardware loaded.  It is not smart enough and the kernel modules don't expose
enough information before being built for us to simply consume `lspci` and
`lsusb` etc.

## Adding to `tinyconfig` (Additive approach)

⚠️ This is still under development and I have not actually attempted runnig a
`tinyconfig` yet!

1. Begin with a `make tinyconfig` that has only the bare minimum set
   ```
   make ARCH=x86_64 LLVM=1 tinyconfig
   ```
2. Run localmodconfig and convert its error messages into modules we must have.
   ```
   make localmodconfig ARCH=x86_64 LLVM=1 2> \
     >(rg -oP 'CONFIG_[^ ]+' | uniq | sort > must_have)
   ```
   If you do not have `rg` installed, use `grep`.
3. Convert the output to a kernel patch that represents the base needs of your
   system.
4. Be sure to set the kernel's `defconfig` argument to `"ARCH=x86_64 allnoconfig
   LLVM=1"` so that you will start with only base NixOS options on top of
   nothing.
5. Fix up dependent options 

This workflow is in my opinion more likely to result in an incomplete boot.
However, because the kernel is so small, it is much faster to rebuild and the
amount of configuration you are handling is much, much less.  **The NixOS options
do turn on way too much, and we might need to bring in extra patches to tone the
driver spam down.**

These systems will not have any cool features turned on.  Cool features are
good.  There is more work to be done.

## Reducing Defconfig (Subtractive Approach)

1. Follow steps 1 and 2 from the 
2. `make localmodconfig` to prune a bunch of settings from your config
3. Diff them.  Now select any large piles of unused things and convert them to
  `structuredExtraConfig` the same as above.
4. Change the kernel to use `"defconfig"` as its `defconfig` (default
  configuration) settings.
5. Fix up dependent options

This workflow is a pain because of the amount of structured config you need to
turn off.  There are easily 3k options you will want to get rid of.

## Other Methods

Parts of workflows that may be useful.

### Make Targets

- `make allmodconfig` - show everything that can be modular
- `make tinyconfig` - a kernel that can minimally boot
- `make allnoconfig` - actually turn off everything, just an emtpy set
- `make savedefconfig` - save's a fragment representing the difference from
  defconfig.
- `make listnewconfig` - show all new things not mentioned in old config

#### Variables

- `KCONFIG_CONFIG` - input / output location
- `KCONFIG_ALLCONFIG` - whatever must be applied to the result
- `ARCH=x86_64` - set the architecture target
- `LLVM=1` - uses the clang + llvm toolchain

#### Architecture & Build Toolchain Dependent

ℹ️ Be sure to use `LLVM=1` on **all** commands when doing work with LLVM.  The
outputs will default to GCC selections if you do not.  Use `ARCH=x86_64` if you
see IA32 active for some reason.

### Script to Flip Individual Config Values

This is what `generate-config.pl` uses.  Run:
- `./scripts/config --unset SCSCI` to turn an option off
- `./scripts/config --set-val SCSI y` to set an option

### Streamlining Script

```bash
perl scripts/kconfig/streamline_config.pl | rg -v \# > minimal.config
```

This script can be a little more direct than `localmodconfig`, but it does output
what looks like a complete config rather than required options.  It is a decent
perl script to perhaps adapt.

## Helpful Nixpkgs to Know

- NixOS default kernel [options](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/common-config.nix)
- Generic
  [kernel](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/generic.nix)
- How NixOS
  [generates](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/generate-config.pl)
  the config
- [structured
  configuration](https://github.com/NixOS/nixpkgs/blob/master/lib/kernel.nix)
  options
  
### Certain Infamous Drivers
- Nvidia [drivers](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11/generic.nix)
- Nvidia open source
  [module](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11/open.nix)
  
  I have no idea how `linuxPackagesFor` relates these things.  Please add this
  information if you know.

## Contribution Ideas

- More pre-made `extraStructuredConfig` to reduce the absurd amount of old
  drivers in defconfig.  We could use sets of things for various purposes and
  accurate usage of `mkDefault` and `mkForce`
- Patches for starting from `tinyconfig` and workflows to obtain the necessary
  `localmodconfig` to have full hardware support
- NixOS modules that encompass the choices better
- Upstream patches to nixpkgs to enable more flexible generic Linux kernel
- Many kernel modules are only likely to be used in rare cases and would
  actually be better of compiled with `-Os` or even compiled on demand (see
  below)
  
## Early Takeaways

- The Linux kernel hardware detection -> kernel config infrastructure is built
  for hackers and server farms but not personal computers.  `lsmod` is too far
  downstream.  We need to base on `lspci` and information we can compile *before
  building or running a kernel*.
- There appears no good way to differentiate a driver from some kernel
  functionality that is modular.  The latter doesn't depend on the presence of
  specific hardware.
- The NixOS kernel build could separate derivations (Kernel2Nix approach) to
  save a lot of time on rebuilds
- If the config itself was a derivation, we could more easily inspect the result
  without building an entire kernel! (can we do this already?)
- The NixOS kernel's common config respects *some* config options but is
  extremely eager to turn on unnecessary options, symptomatic of being intended
  for mass consumption of a vanilla kernel rather than cooperative settings in
  NixOS.
- NixOS common config cannot pass its own perl script against tinyconfig, so
  much of our configuration dependencies are possibly coming form defconfig.

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
- There are several patch <-> Nix conversion problems / opportunities that could
  be useful during initial installation.

## Shameless Self-Promotion 💸

This work was produced in the course of building
[PrizeForge.com](prizeforge.com).  You can consider it as a tip jar, but it will
be much more.  It is a community tip char where we users will drive development
by showing open source authors, maintainers, and contributors, what we want them
to work on.  In the course of deciding what to work on, users will provide each
other support.  Good support comes from people who know what needs to be done.
When good users who give support are able to decide what to work on, the people
who understand users are talking to the people who build the programs.

Give me a monetary tip to accelerate its development.  As soon as it is
underway, the world will move faster with more open source, more open IP in
general, and less stupid competition.
