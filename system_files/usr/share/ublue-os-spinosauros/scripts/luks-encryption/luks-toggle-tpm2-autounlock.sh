#!/bin/bash
## Toggle TPM2 auto-unlock for LUKS2 encrypted root
## Fedora / Silverblue / rpm-ostree systems

set -euo pipefail

# Prompt for sudo/root at the start
if [[ $EUID -ne 0 ]]; then
  echo "This script requires root privileges."
  exec sudo "$0" "$@"
fi

#######################################
# Shared helper functions
#######################################

get_crypt_disk() {
  ## Inspect Kernel Cmdline for rd.luks.uuid
  RD_LUKS_UUID="$(xargs -n1 -a /proc/cmdline | grep rd.luks.uuid | cut -d = -f 2)"

  # Check to make sure cmdline rd.luks.uuid exists
  if [[ -z ${RD_LUKS_UUID:-} ]]; then
    echo "LUKS device not defined on Kernel Commandline."
    echo "This is not supported by this script."
    exit 1
  fi

  # Check to make sure that the specified cmdline uuid exists.
  if ! grep -q "${RD_LUKS_UUID}" <<< "$(lsblk)"; then
    echo "LUKS device not listed in block devices."
    exit 1
  fi

  # Cut off luks- prefix
  LUKS_PREFIX="luks-"
  if grep -q "^${LUKS_PREFIX}" <<< "${RD_LUKS_UUID}"; then
    DISK_UUID=${RD_LUKS_UUID#"$LUKS_PREFIX"}
  else
    echo "LUKS UUID format mismatch."
    exit 1
  fi

  # Specify Crypt Disk by-uuid
  CRYPT_DISK="/dev/disk/by-uuid/$DISK_UUID"

  # Check to make sure crypt disk exists
  if [[ ! -L "$CRYPT_DISK" ]]; then
    echo "LUKS device not listed in block devices."
    exit 1
  fi
}

#######################################
# Disable TPM2 auto-unlock
#######################################

disable_tpm2() {
  echo
  echo "This will DISABLE TPM2 auto-unlock for your LUKS root device."
  read -rp "Continue? (y/N): " -n 1 -r
  echo

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi

  get_crypt_disk

  ## Restore crypttab if backup exists
  cp -a /etc/crypttab /etc/crypttab.working-before-disable-tpm2

  if [[ -f /etc/crypttab.known-good ]]; then
    echo "Restoring /etc/crypttab.known-good to /etc/crypttab"
    mv /etc/crypttab.known-good /etc/crypttab
  fi

  ## Wipe TPM2 slot
  if cryptsetup luksDump "$CRYPT_DISK" | grep -q systemd-tpm2; then
    echo "Removing TPM2 enrollment from $CRYPT_DISK"
    systemd-cryptenroll --wipe-slot=tpm2 "$CRYPT_DISK"
  else
    echo "No TPM2 enrollment found."
  fi

  ## Disable initramfs TPM support
  if rpm-ostree initramfs | grep -q tpm2; then
    echo
    echo "WARNING: this disables custom rpm-ostree initramfs configuration."
    rpm-ostree initramfs
    echo

    read -rp "Disable rpm-ostree initramfs TPM config? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rpm-ostree initramfs --disable
    fi
  else
    echo "TPM2 not configured in rpm-ostree initramfs."
  fi

  echo
  echo "TPM2 auto-unlock disabled."
}

#######################################
# Enable TPM2 auto-unlock
#######################################

enable_tpm2() {
  echo
  echo "WARNING: Do NOT use this if your CPU is vulnerable to faulTPM!"
  echo "AMD Zen2 and Zen3 processors are known affected."
  echo
  echo "This will ENABLE TPM2 auto-unlock for your LUKS root device."
  echo "PCRs used: 7 + 14 (Secure Boot + MOK state)"
  echo

  read -rp "Continue? (y/N): " -n 1 -r
  echo

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi

  get_crypt_disk

  SET_PIN_ARG=""

  read -rp "Would you like to require a TPM PIN? (y/N): " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    SET_PIN_ARG="--tpm2-with-pin=yes"
  fi

  ## Existing TPM2 enrollment
  if cryptsetup luksDump "$CRYPT_DISK" | grep -q systemd-tpm2; then
    KEYSLOT=$(
      cryptsetup luksDump "$CRYPT_DISK" \
        | sed -n '/systemd-tpm2$/,/Keyslot:/p' \
        | grep Keyslot \
        | awk '{print $2}'
    )

    echo
    echo "TPM2 already enrolled in keyslot $KEYSLOT."

    read -rp "Wipe and re-enroll TPM2? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      systemd-cryptenroll --wipe-slot=tpm2 "$CRYPT_DISK"
    else
      echo "Leaving existing TPM2 enrollment untouched."
      exit 1
    fi
  fi

  ## Enroll TPM2
  echo
  echo "You will now be prompted for your existing LUKS password."
  echo

  systemd-cryptenroll \
    --tpm2-device=auto \
    --tpm2-pcrs=7+14 \
    $SET_PIN_ARG \
    "$CRYPT_DISK"

  ## Configure initramfs
  if lsinitrd 2>&1 | grep -q tpm2-tss; then
    if rpm-ostree initramfs | grep -q tpm2; then
      echo "TPM2 already present in rpm-ostree initramfs config."
      rpm-ostree initramfs
      echo "Rebuilding initramfs..."
    fi

    rpm-ostree initramfs --enable --arg=--force-add --arg=tpm2-tss
  else
    echo "TPM2 support already present in initramfs."
  fi

  echo
  echo "TPM2 auto-unlock configured."
  echo "Reboot to test."
}

#######################################
# Menu
#######################################

echo "========================================="
echo " TPM2 LUKS Auto-Unlock Manager"
echo "========================================="
echo
echo "1) Enable TPM2 auto-unlock"
echo "2) Disable TPM2 auto-unlock"
echo "3) Exit"
echo

read -rp "Choose an option [1-3]: " CHOICE

case "$CHOICE" in
  1)
    enable_tpm2
    ;;
  2)
    disable_tpm2
    ;;
  3)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid option."
    exit 1
    ;;
esac
