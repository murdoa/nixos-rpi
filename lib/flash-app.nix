{ nixpkgs }:
{
  image,
  name ? "flash-image",
  deviceById ? null,
}:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  usage = if deviceById == null then "Usage: $0 <device>" else "Usage: $0";
  deviceHelp = if deviceById == null then "Target device must be passed explicitly, e.g. /dev/sdX or /dev/disk/by-id/..." else "Writes only to the configured device:\n  ${deviceById}";
  deviceAssignment = if deviceById == null then ''
    if [ $# -ne 1 ]; then
      echo "${usage}"
      echo ""
      echo "${deviceHelp}"
      exit 1
    fi

    DEVICE="$1"
  '' else ''
    if [ $# -ne 0 ]; then
      echo "${usage}"
      exit 1
    fi

    DEVICE="${deviceById}"
  '';
in
{
  type = "app";
  program = toString (
    pkgs.writeShellScript name ''
      set -euo pipefail

      export PATH="${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.util-linux pkgs.pv ]}:$PATH"

      if [[ "''${1:-}" == "--help" || "''${1:-}" == "-h" ]]; then
        echo "${usage}"
        echo ""
        echo "Flash ${image}/image.raw to an SD card."
        echo ""
        echo "${deviceHelp}"
        echo ""
        echo "Safety checks:"
        echo "- resolves symlinks to the real block device"
        echo "- refuses non-block devices"
        echo "- refuses non-removable devices"
        echo "- requires interactive 'yes' confirmation"
        exit 0
      fi

      ${deviceAssignment}

      IMAGE="${image}/image.raw"

      if [ ! -e "$DEVICE" ]; then
        echo "ERROR: Device $DEVICE does not exist"
        exit 1
      fi

      REAL_DEV=$(readlink -f "$DEVICE")

      if [ ! -b "$REAL_DEV" ]; then
        echo "ERROR: $DEVICE resolved to $REAL_DEV, which is not a block device"
        exit 1
      fi

      BLOCK_NAME=$(basename "$REAL_DEV")
      REMOVABLE=$(cat "/sys/block/$BLOCK_NAME/removable" 2>/dev/null || true)

      if [ "$REMOVABLE" != "1" ]; then
        echo "ERROR: $REAL_DEV is not a removable device. Refusing to continue."
        exit 1
      fi

      SIZE=$(lsblk -bdno SIZE "$REAL_DEV" 2>/dev/null || true)
      if [ -n "$SIZE" ]; then
        SIZE_GB=$(( SIZE / 1073741824 ))
        SIZE_TEXT="''${SIZE_GB}GB"
      else
        SIZE_TEXT="unknown size"
      fi

      echo "Image:  $IMAGE"
      echo "Target: $DEVICE -> $REAL_DEV ($SIZE_TEXT)"
      echo ""
      echo "THIS WILL ERASE ALL DATA ON THE TARGET DEVICE."
      read -r -p "Type 'yes' to continue: " CONFIRM
      if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 1
      fi

      echo "Flashing..."
      pv -f -p -t -e -r -b -s "$(stat -c%s "$IMAGE")" "$IMAGE" | sudo dd of="$REAL_DEV" bs=8M iflag=fullblock oflag=direct status=none conv=fsync
      sudo sync
      echo "Done."
    ''
  );
}
