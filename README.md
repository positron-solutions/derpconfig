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
- [examples/kernel-clang.nix](examples/kernel-clang.nix) contains an example
  kernel configuration building with LLVM and clang.  **The nvidia kernel module
  must be derived from your kernel** as shown **and included into your kernel
  modules** or problems are easy to run into.
- [examples/tiny-boot.nix](examples/tiny-boot.nix) shows how to deal with a
  relatively small boot partition, reducing the initrd and maximally compressing
  the kernel (requires almost no time to save a little disk space).

### Not a Library

**This repo is more exploratory and demonstrative than intended for blind
consumption**.  Run your own scripts.  🙅 Kernel versions add options.  NixOS
modules change See `make oldconfig`.

Options used are **not** portable.  You **must** set your CPU architecture
correctly when using `-mtune` and `-march`.  There is a way to adapt the
`stdenv` to use `-march=native`, which is an impurity, but you can also use the
compilers inside the shell and just match up with your CPU:

<details>
<summary>on clang</summary>

```bash
llc -march=x86 -mattr=help
Available CPUs for this target:

  alderlake               - Select the alderlake processor.
  amdfam10                - Select the amdfam10 processor.
  arrowlake               - Select the arrowlake processor.
  arrowlake-s             - Select the arrowlake-s processor.
  arrowlake_s             - Select the arrowlake_s processor.
  athlon                  - Select the athlon processor.
  athlon-4                - Select the athlon-4 processor.
  athlon-fx               - Select the athlon-fx processor.
  athlon-mp               - Select the athlon-mp processor.
  athlon-tbird            - Select the athlon-tbird processor.
  athlon-xp               - Select the athlon-xp processor.
  athlon64                - Select the athlon64 processor.
  athlon64-sse3           - Select the athlon64-sse3 processor.
  atom                    - Select the atom processor.
  atom_sse4_2             - Select the atom_sse4_2 processor.
  atom_sse4_2_movbe       - Select the atom_sse4_2_movbe processor.
  barcelona               - Select the barcelona processor.
  bdver1                  - Select the bdver1 processor.
  bdver2                  - Select the bdver2 processor.
  bdver3                  - Select the bdver3 processor.
  bdver4                  - Select the bdver4 processor.
  bonnell                 - Select the bonnell processor.
  broadwell               - Select the broadwell processor.
  btver1                  - Select the btver1 processor.
  btver2                  - Select the btver2 processor.
  c3                      - Select the c3 processor.
  c3-2                    - Select the c3-2 processor.
  cannonlake              - Select the cannonlake processor.
  cascadelake             - Select the cascadelake processor.
  clearwaterforest        - Select the clearwaterforest processor.
  cooperlake              - Select the cooperlake processor.
  core-avx-i              - Select the core-avx-i processor.
  core-avx2               - Select the core-avx2 processor.
  core2                   - Select the core2 processor.
  core_2_duo_sse4_1       - Select the core_2_duo_sse4_1 processor.
  core_2_duo_ssse3        - Select the core_2_duo_ssse3 processor.
  core_2nd_gen_avx        - Select the core_2nd_gen_avx processor.
  core_3rd_gen_avx        - Select the core_3rd_gen_avx processor.
  core_4th_gen_avx        - Select the core_4th_gen_avx processor.
  core_4th_gen_avx_tsx    - Select the core_4th_gen_avx_tsx processor.
  core_5th_gen_avx        - Select the core_5th_gen_avx processor.
  core_5th_gen_avx_tsx    - Select the core_5th_gen_avx_tsx processor.
  core_aes_pclmulqdq      - Select the core_aes_pclmulqdq processor.
  core_i7_sse4_2          - Select the core_i7_sse4_2 processor.
  corei7                  - Select the corei7 processor.
  corei7-avx              - Select the corei7-avx processor.
  emeraldrapids           - Select the emeraldrapids processor.
  generic                 - Select the generic processor.
  geode                   - Select the geode processor.
  goldmont                - Select the goldmont processor.
  goldmont-plus           - Select the goldmont-plus processor.
  goldmont_plus           - Select the goldmont_plus processor.
  gracemont               - Select the gracemont processor.
  grandridge              - Select the grandridge processor.
  graniterapids           - Select the graniterapids processor.
  graniterapids-d         - Select the graniterapids-d processor.
  graniterapids_d         - Select the graniterapids_d processor.
  haswell                 - Select the haswell processor.
  i386                    - Select the i386 processor.
  i486                    - Select the i486 processor.
  i586                    - Select the i586 processor.
  i686                    - Select the i686 processor.
  icelake-client          - Select the icelake-client processor.
  icelake-server          - Select the icelake-server processor.
  icelake_client          - Select the icelake_client processor.
  icelake_server          - Select the icelake_server processor.
  ivybridge               - Select the ivybridge processor.
  k6                      - Select the k6 processor.
  k6-2                    - Select the k6-2 processor.
  k6-3                    - Select the k6-3 processor.
  k8                      - Select the k8 processor.
  k8-sse3                 - Select the k8-sse3 processor.
  knl                     - Select the knl processor.
  knm                     - Select the knm processor.
  lakemont                - Select the lakemont processor.
  lunarlake               - Select the lunarlake processor.
  meteorlake              - Select the meteorlake processor.
  mic_avx512              - Select the mic_avx512 processor.
  nehalem                 - Select the nehalem processor.
  nocona                  - Select the nocona processor.
  opteron                 - Select the opteron processor.
  opteron-sse3            - Select the opteron-sse3 processor.
  pantherlake             - Select the pantherlake processor.
  penryn                  - Select the penryn processor.
  pentium                 - Select the pentium processor.
  pentium-m               - Select the pentium-m processor.
  pentium-mmx             - Select the pentium-mmx processor.
  pentium2                - Select the pentium2 processor.
  pentium3                - Select the pentium3 processor.
  pentium3m               - Select the pentium3m processor.
  pentium4                - Select the pentium4 processor.
  pentium4m               - Select the pentium4m processor.
  pentium_4               - Select the pentium_4 processor.
  pentium_4_sse3          - Select the pentium_4_sse3 processor.
  pentium_ii              - Select the pentium_ii processor.
  pentium_iii             - Select the pentium_iii processor.
  pentium_iii_no_xmm_regs - Select the pentium_iii_no_xmm_regs processor.
  pentium_m               - Select the pentium_m processor.
  pentium_mmx             - Select the pentium_mmx processor.
  pentium_pro             - Select the pentium_pro processor.
  pentiumpro              - Select the pentiumpro processor.
  prescott                - Select the prescott processor.
  raptorlake              - Select the raptorlake processor.
  rocketlake              - Select the rocketlake processor.
  sandybridge             - Select the sandybridge processor.
  sapphirerapids          - Select the sapphirerapids processor.
  sierraforest            - Select the sierraforest processor.
  silvermont              - Select the silvermont processor.
  skx                     - Select the skx processor.
  skylake                 - Select the skylake processor.
  skylake-avx512          - Select the skylake-avx512 processor.
  skylake_avx512          - Select the skylake_avx512 processor.
  slm                     - Select the slm processor.
  tigerlake               - Select the tigerlake processor.
  tremont                 - Select the tremont processor.
  westmere                - Select the westmere processor.
  winchip-c6              - Select the winchip-c6 processor.
  winchip2                - Select the winchip2 processor.
  x86-64                  - Select the x86-64 processor.
  x86-64-v2               - Select the x86-64-v2 processor.
  x86-64-v3               - Select the x86-64-v3 processor.
  x86-64-v4               - Select the x86-64-v4 processor.
  yonah                   - Select the yonah processor.
  znver1                  - Select the znver1 processor.
  znver2                  - Select the znver2 processor.
  znver3                  - Select the znver3 processor.
  znver4                  - Select the znver4 processor.
  znver5                  - Select the znver5 processor.
 ```

</details>

<details>
<summary>on gcc</summary>

```bash
gcc --target-help

  Known valid arguments for -march= option:
    i386 i486 i586 pentium lakemont pentium-mmx winchip-c6 winchip2 c3 samuel-2 c3-2 nehemiah c7 esther i686 pentiumpro pentium2 pentium3 pentium3m pentium-m pentium4 pentium4m prescott nocona core2 nehalem corei7 westmere sandybridge corei7-avx ivybridge core-avx-i haswell core-avx2 broadwell skylake skylake-avx512 cannonlake icelake-client rocketlake icelake-server cascadelake tigerlake cooperlake sapphirerapids emeraldrapids alderlake raptorlake meteorlake graniterapids graniterapids-d arrowlake arrowlake-s lunarlake pantherlake bonnell atom silvermont slm goldmont goldmont-plus tremont gracemont sierraforest grandridge clearwaterforest knl knm intel geode k6 k6-2 k6-3 athlon athlon-tbird athlon-4 athlon-xp athlon-mp x86-64 x86-64-v2 x86-64-v3 x86-64-v4 eden-x2 nano nano-1000 nano-2000 nano-3000 nano-x2 eden-x4 nano-x4 lujiazui yongfeng k8 k8-sse3 opteron opteron-sse3 athlon64 athlon64-sse3 athlon-fx amdfam10 barcelona bdver1 bdver2 bdver3 bdver4 znver1 znver2 znver3 znver4 znver5 btver1 btver2 generic native

  Known valid arguments for -mtune= option:
    generic i386 i486 pentium lakemont pentiumpro pentium4 nocona core2 nehalem sandybridge haswell bonnell silvermont goldmont goldmont-plus tremont sierraforest grandridge clearwaterforest knl knm skylake skylake-avx512 cannonlake icelake-client icelake-server cascadelake tigerlake cooperlake sapphirerapids alderlake rocketlake graniterapids graniterapids-d arrowlake arrowlake-s pantherlake intel lujiazui yongfeng geode k6 athlon k8 amdfam10 bdver1 bdver2 bdver3 bdver4 btver1 btver2 znver1 znver2 znver3 znver4 znver5
```

</details>

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
