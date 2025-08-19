{ config, pkgs, lib, ...}:

{
  # .:: Tiny boot partion options included below
  #
  # Result is about 22MB for one kernel and initrd.  which makes it easy to fit
  # on my anemically chosen boot partition.
  #
  # Note, compressor can go higher but warned with these settings and reverted
  # to 19.  Zstd decompresses fast, and that's good for boot time.
  boot.initrd.compressorArgs = ["-22" "-T0" "--long" "--ultra"];
  # ⚠️ You will not have any fallback generations with this setting!  Only use if
  # you have an external recovery disk and know how to use nixos-enter for
  # system recovery!
  boot.loader.systemd-boot.configurationLimit = 1;
  boot.initrd.includeDefaultModules = false;

  # Imagine what can go wrong before you try to reboot!
  boot.initrd.luks.cryptoModules = [
    "aes"
    "xts"
    "sha256_generic"
  ];

  # When you set kernel modules this way, you have to get them all right or you
  # will not be able to boot.
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
