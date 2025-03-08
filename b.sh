#!/bin/bash

# Update package list and install QEMU-KVM
echo "Updating package list..."
sudo apt update
sudo apt install -y qemu-kvm unzip cpulimit python3-pip
if [ $? -ne 0 ]; then
    echo "Error while updating and installing required packages. Please check."
    exit 1
fi

# Check if /mnt is mounted
echo "Checking if partition is mounted to /mnt..."
if mount | grep "on /mnt " > /dev/null; then
    echo "Partition is already mounted to /mnt. Continuing..."
else
    echo "Partition is not mounted. Searching for a partition larger than 500GB..."
    partition=$(lsblk -b --output NAME,SIZE,MOUNTPOINT | awk '$2 > 500000000000 && $3 == "" {print $1}' | head -n 1)

    if [ -n "$partition" ]; then
        echo "Found partition: /dev/$partition"
        sudo mount "/dev/${partition}1" /mnt
        if [ $? -ne 0 ]; then
            echo "Error while mounting partition. Please check."
            exit 1
        fi
        echo "Partition /dev/$partition has been mounted to /mnt."
    else
        echo "No partition larger than 500GB found that is not mounted. Please check."
        exit 1
    fi
fi

# Display OS selection menu
echo "Select an operating system to run the VM:"
echo "1. Windows 10"
echo "2. Windows 11"

read -p "Enter your choice (1 or 2): " user_choice

if [ "$user_choice" -eq 1 ]; then
    echo "You have selected Windows 10."
    file_url="https://github.com/jshruwyd/discord-vps-creator/raw/refs/heads/main/a.py"
    file_name="a.py"
elif [ "$user_choice" -eq 2 ]; then
    echo "You have selected Windows 11."
    file_url="https://github.com/jshruwyd/discord-vps-creator/raw/refs/heads/main/b.py"
    file_name="b.py"
else
    echo "Invalid choice. Please run the script again and select 1 or 2."
    exit 1
fi

# Download Python file
echo "Downloading file $file_name from $file_url..."
wget -O "/mnt/$file_name" "$file_url"
if [ $? -ne 0 ]; then
    echo "Error downloading file. Please check your network connection or URL."
    exit 1
fi

# Install gdown and run Python file
echo "Installing gdown and running file $file_name..."
pip install gdown
python3 "/mnt/$file_name"
if [ $? -ne 0 ]; then
    echo "Error running Python file. Please check."
    exit 1
fi

# Wait 3 seconds after running the Python file
echo "Waiting 5 seconds before continuing..."
sleep 5

# Extract all .zip files in the /mnt directory
echo "Extracting all .zip files in /mnt..."
unzip '/mnt/*.zip' -d /mnt/
if [ $? -ne 0 ]; then
    echo "Error extracting files. Please check the downloaded files."
    exit 1
fi

# Start the virtual machine with KVM
echo "Starting the virtual machine..."
echo "VM started successfully, please install ngrok and open port 5900."
sudo cpulimit -l 80 -- sudo kvm \
    -cpu host,+topoext,hv_relaxed,hv_spinlocks=0x1fff,hv-passthrough,+pae,+nx,kvm=on,+svm \
    -smp 2,cores=2 \
    -M q35,usb=on \
    -device usb-tablet \
    -m 4G \
    -device virtio-balloon-pci \
    -vga virtio \
    -net nic,netdev=n0,model=virtio-net-pci \
    -netdev user,id=n0,hostfwd=tcp::3389-:3389 \
    -boot c \
    -device virtio-serial-pci \
    -device virtio-rng-pci \
    -enable-kvm \
    -hda /mnt/a.qcow2 \
    -drive if=pflash,format=raw,readonly=off,file=/usr/share/ovmf/OVMF.fd \
    -uuid e47ddb84-fb4d-46f9-b531-14bb15156336 \
    -vnc :0
# Check if noVNC is already installed
if [ ! -d "/mnt/noVNC" ]; then
    echo "noVNC not found, cloning the repository..."
    git clone https://github.com/novnc/noVNC.git /mnt/noVNC
    cd /mnt/noVNC
    chmod +x *
    echo "noVNC cloned successfully. Starting novnc_proxy..."
    ./utils/novnc_proxy --vnc localhost:5900 &
else
    echo "noVNC is already installed. Starting novnc_proxy..."
    cd /mnt/noVNC
    ./utils/novnc_proxy --vnc localhost:5900 &
fi
