#!/bin/bash
# This script automates the process of mounting a NAS share via CIFS for a Frigate container.
# It stops the Frigate service, backs up the current data, creates a credentials file,
# appends an fstab entry (with rw and nofail options), mounts the share, copies data,
# and finally restarts the Frigate service.

# Ensure the script is run as root.
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

# Check for required packages: cifs-utils and smbclient.
if ! command -v mount.cifs >/dev/null 2>&1; then
    echo "Error: cifs-utils is not installed. Please install it first."
    exit 1
fi

if ! command -v smbclient >/dev/null 2>&1; then
    echo "Error: smbclient is not installed. Please install it first."
    exit 1
fi

#############################
# Define variables:
#############################
SERVER="10.10.2.10"                # IP or hostname of your NAS
SHARE="frigatemedia"               # Adjust if your share name differs.
MOUNTPOINT="/media/frigate"        # Mount point where Frigate stores its data.
CIFS_USER="frigate"                # The username for the smb share from the NAS
CIFS_PASS="supersecretpasswordhere"        # Update if your password changes.
CRED_DIR="/etc/cifs-credentials"
CRED_FILE="${CRED_DIR}/${SHARE}.cred"

# fstab entry with rw and nofail options.
FSTAB_ENTRY="//${SERVER}/${SHARE} ${MOUNTPOINT} cifs credentials=${CRED_FILE},rw,nofail,iocharset=utf8 0 0"

#############################
# Stop Frigate Service:
#############################
echo "Stopping Frigate service..."
systemctl stop frigate

#############################
# Backup existing Frigate directory:
#############################
BACKUP_DIR="/media/frigate_backup_$(date +%F-%T)"
echo "Backing up ${MOUNTPOINT} to ${BACKUP_DIR}..."
cp -a "${MOUNTPOINT}" "${BACKUP_DIR}"

#############################
# Create credentials file:
#############################
if [ ! -d "$CRED_DIR" ]; then
    mkdir -p "$CRED_DIR"
fi

cat <<EOF > "$CRED_FILE"
username=${CIFS_USER}
password=${CIFS_PASS}
EOF

chmod 600 "$CRED_FILE"
echo "Created credentials file at ${CRED_FILE}."

#############################
# Create mount point (if it doesn't exist):
#############################
if [ ! -d "$MOUNTPOINT" ]; then
    mkdir -p "$MOUNTPOINT"
    echo "Created mount point at ${MOUNTPOINT}."
fi

#############################
# Backup current /etc/fstab:
#############################
FSTAB_BACKUP="/etc/fstab.bak.$(date +%F-%T)"
cp /etc/fstab "$FSTAB_BACKUP"
echo "Backup of /etc/fstab saved to ${FSTAB_BACKUP}."

#############################
# Append fstab entry:
#############################
if grep -qs "${MOUNTPOINT}" /etc/fstab; then
    echo "An fstab entry for ${MOUNTPOINT} already exists."
else
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo "Added fstab entry:"
    echo "$FSTAB_ENTRY"
fi

#############################
# Mount the NAS share:
#############################
echo "Mounting filesystems..."
mount -a

if mountpoint -q "$MOUNTPOINT"; then
    echo "${MOUNTPOINT} is successfully mounted."
else
    echo "Mounting failed. Please check your configuration."
    exit 1
fi

#############################
# Copy backup data to the mounted directory:
#############################
echo "Copying backup data from ${BACKUP_DIR} to ${MOUNTPOINT}..."
cp -a "${BACKUP_DIR}"/* "${MOUNTPOINT}/"

#############################
# Restart Frigate Service:
#############################
echo "Starting Frigate service..."
systemctl start frigate

echo "Operation complete. Verify that Frigate is running correctly and using data from ${MOUNTPOINT}."
