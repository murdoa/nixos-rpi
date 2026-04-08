{ nixpkgs }:
image:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
in
{
  type = "app";
  program = toString (
    pkgs.writeShellScript "flash-image" ''
      set -euo pipefail

      if [ $# -ne 1 ]; then
        echo "Usage: $0 <device>"
        echo "Example: $0 /dev/sdc"
        exit 1
      fi

      DEVICE="$1"
      IMAGE="${image}/image.raw"

      if [ ! -e "$DEVICE" ]; then
        echo "Error: Device $DEVICE does not exist"
        exit 1
      fi

      if [ ! -b "$DEVICE" ]; then
        echo "Error: $DEVICE is not a block device"
        exit 1
      fi

      echo "Flashing $IMAGE to $DEVICE..."
      ${pkgs.pv}/bin/pv -s "$(stat -c%s "$IMAGE")" "$IMAGE" | sudo ${pkgs.coreutils}/bin/dd of="$DEVICE" bs=8M oflag=direct status=progress conv=fsync
      sync
      echo "Done"
    ''
  );
}
