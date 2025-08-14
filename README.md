# DerpConfig

Small setup for iterating on NixOS kernel configs.  People do this to obtain
smaller and faster kernels that build faster and do other things just the way
that they want.

Using Kernel customizations will require re-building every time you update
nixpkgs or change its configuration.

ℹ️ The flake contains versions and pins that will affect your results.

## Using the shell

1. Update the flake.nix to point nixpkgs to the rev you intend to upgrade to
1. `nix build` to obtain a `result` that points to the linux src tarball.
1. `tar -xvf result` to obtain linux-6.16.0 etc
1. `direnv allow` or `nix develop` to obtain tools necessary for the configuration make targets
1. Inside the linux src, run `make menuconfig` and you should see a config.

## Hacking on Your Config

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
1. Create a kernel patch with `extraStructuredConfig` that can be merged on top
   of options set by NixOS in [the
   defaults](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/common-config.nix).
   This must be added to `boot.kernelPatches`.
```ChatGPT
   Dear Sam, please convert the following lines of Linux kernel config to NixOS
   extraStructured config within a kernel patch for boot.kernelPatches.  Use
   lib.kernel to coerce choices to the correct format.  Use mkForce when
   disabling.  Indent to zero spaces.
```
1. `nixos-rebuild switch` and it takes about an hour on a five year-old laptop
   unless you have significantly reduced the drivers and things.  💡 **The first
   runs will likely not be successful**!  NixOS runs a script that will identify
   unused options.  That were disabled as a result of the ones you selected.
   Just add them to the pile 2-3 times and you will have reached a stable fixed
   point.

## Contributing Ideas

- More pre-made `extraStructuredConfig` to reduce the absurd amount of old
  drivers in defconfig.  We could use sets of things for various purposes and
  accurate useage of `mkDefault` and `mkForce`
- NixOS modules for faster application of changes.
- Upstream patches to enable more flexible generic Linux kernel
