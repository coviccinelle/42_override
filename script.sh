#!/bin/bash

# ISO path
ISO_PATH="$HOME/Downloads/OverRide.iso"

# Check if the ISO file exists
if [ ! -f "$ISO_PATH" ]; then
    echo "err: ISO not found at $ISO_PATH"
    echo "Please check the path and try again."
    exit 1
fi

echo "running OverRide VM..."
echo "- Web: http://localhost:8080"
echo "- SSH: ssh [user]@localhost -p 4242"

# QEMU command to run the VM
qemu-system-x86_64 \
    -m 1024 \
    -cpu qemu64 \
    -cdrom "$ISO_PATH" \
    -boot d \
    -net nic \
    -net user,hostfwd=tcp::8080-:80,hostfwd=tcp::4242-:4242
