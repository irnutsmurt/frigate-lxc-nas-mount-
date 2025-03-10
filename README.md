---

# Frigate NAS Mount Guide for Proxmox LXC

This guide explains how to mount a NAS share via SMB using CIFS in your Proxmox LXC container running Frigate. You can either follow the manual steps or use the provided bash script to automate much of the process.

---

## Overview

The process includes:

1. Stopping the Frigate service.
2. Backing up the existing Frigate data directory.
3. Creating a secure credentials file.
4. Appending an fstab entry with `rw` (read-write) and `nofail` options.
5. Mounting the NAS share.
6. Copying the existing data to the mounted share.
7. Restarting the Frigate service.

---

## Pre-requisites

- **Access to the container:** SSH into your Frigate LXC container or use the Proxmox console.
- **Required packages:** Make sure `cifs-utils` and `smbclient` are installed inside of the frigate lxc already. This can be done using `apt install cifs-utils smbclient -y`

---

## Manual Steps

1. **Stop the Frigate Service:**  
   ```
   systemctl stop frigate
   ```

2. **Back Up the Existing Data:**  
   ```
   cp -a /media/frigate /media/frigate_backup
   ```

3. **Create a Credentials File:**  
   ```
   mkdir -p /etc/cifs-credentials
   cat <<EOF > /etc/cifs-credentials/frigate.cred
   username=frigate
   password=d[dknffsddc120!f
   EOF
   chmod 600 /etc/cifs-credentials/frigate.cred
   ```

4. **Append the fstab Entry:**  
   Edit `/etc/fstab` by adding this line (adjust as needed):  
   ```
   echo "//10.10.2.10/frigatemedia  /media/frigate  cifs credentials=/etc/cifs-credentials/frigate.cred,rw,nofail,iocharset=utf8  0 0" >> /etc/fstab
   ```

5. **Mount the NAS Share:**  
   ```
   mount -a
   ```
   Verify with:
   ```
   mountpoint -q /media/frigate && echo "Mounted successfully" || echo "Mount failed"
   ```

6. **Copy the Backup Data:**  
   ```
   cp -a /media/frigate_backup/* /media/frigate/
   ```

7. **Restart the Frigate Service:**  
   ```
   systemctl start frigate
   ```
   Verify with:
   ```
   systemctl status frigate
   ```

---

## Automated Bash Script

We’ve created a bash script (`frigatemount.sh`) that automates the above steps. The script also checks for the required packages and sets up the credentials file and fstab entry with `rw` and `nofail` options.

### Editing the Script Variables

At the top of the script, you’ll see variables that need to be set to match your environment. Here’s what each variable represents:

- **SERVER:**  
  This is the NAS IP address.  
  ```
  SERVER="10.10.2.10"
  ```  
  *Keep the quotes. Replace the IP the IP of your NAS.*

- **SHARE:**  
  This should be set to the NAS share name.  
  For example, if your NAS share is accessible via the path `10.10.2.10:mediaserver/storage/frigate01`, set it like:  
  ```
  SHARE="mediaserver/storage/frigate01"
  ```  
  *Do not include the NAS IP here since it’s already specified in SERVER.*

- **MOUNTPOINT:**  
  This is the local directory on your frigate lxc where the share will be mounted. Note: if you have haven't moved the existing data out of the /media/frigate directory already, do so or this will fail.
  ```
  MOUNTPOINT="/media/frigate"
  ```

- **CIFS_USER & CIFS_PASS:**  
  Set these to the NAS credentials for accessing the share.  
  ```
  CIFS_USER="frigate"
  CIFS_PASS="yourverysecretpassword"
  ```

The script uses these variables to construct the fstab entry as follows:
```
FSTAB_ENTRY="//${SERVER}/${SHARE} ${MOUNTPOINT} cifs credentials=${CRED_FILE},rw,nofail,iocharset=utf8 0 0"
```
---

## Usage

1. **Edit the Script Variables:**  
   Open `frigatemount.sh` in a text editor and modify the variables at the top as explained above.  
   - For example, if your NAS IP is `10.10.2.10` (leave it as is) and your share is named `mediaserver/storage/frigate01`, then set:
     ```
     SERVER="10.10.2.10"
     SHARE="mediaserver/storage/frigate01"
     ```
   - Adjust `MOUNTPOINT`, `CIFS_USER`, and `CIFS_PASS` if needed.

2. **Upload the Script to Your Container:**  
   Place the script in your Frigate container.

3. **Make the Script Executable and Run It:**  
   ```
   chmod +x frigatemount.sh
   sudo ./frigatemount.sh
   ```

4. **Verify:**  
   Check that the NAS share is mounted at `/media/frigate` and that Frigate is running correctly.

---

## Final Notes

- **Access Method:** Always log into your Frigate container via SSH or use the Proxmox console before running any commands.
