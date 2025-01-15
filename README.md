# Setup VPS for Debian

Welcome to this guide on setting up your VPS for Debian! This document outlines the steps to initialize your VPS, configure SSH access, and execute the setup script. Follow these instructions to streamline your VPS configuration process. 🚀

---

## **Prerequisites**
- 🌐 A Debian-based VPS.
- 🔐 SSH access to your VPS.
- 💻 A terminal on your local machine with SSH installed.

---

## **What Does the Setup Script Do?**
The script automates the essential tasks to secure and configure your VPS. Here's what it includes:

1. 🛠️ **Creates an admin user** and sets up SSH keys for secure access.
2. 🔒 **Secures SSH configuration** (port, disables root login, enforces public key authentication).
3. 📦 **Updates the system** and installs basic tools.
4. 🛡️ **Configures a firewall** using UFW.
5. 👮 **Installs and sets up Fail2Ban** for intrusion prevention.
6. ⏰ **Sets the timezone** and disables unnecessary services.
7. 🐳 **Installs Docker** for containerization.
8. 🔄 **Tests SSH connectivity**.
9. 🎨 **Installs Zsh**, Oh My Zsh, and the Powerlevel10k theme for a beautiful shell.
10. 🧹 **Cleans up default settings** and removes unused accounts.

At the end, the script provides a summary of the status of each section. ✅❌

---

## **Step-by-Step Instructions**

### 1. **Generate an SSH Key Pair**
On your local machine, navigate to your SSH directory and generate a new SSH key pair:

```bash
cd ~/.ssh
ssh-keygen -t ed25519 -C "MonVPS" -f id_monvps
```
- `-t ed25519`: Specifies the key type.
- `-C "MonVPS"`: Adds a comment to identify the key.
- `-f id_monvps`: Defines the file name for the key pair.

---

### 2. **Initial Connection to the VPS**
Use the default credentials provided by your VPS provider to connect for the first time:

```bash
ssh debian@<IP>
```
Replace `<IP>` with the IP address of your VPS.

---

### 3. **Copy Your Public SSH Key to the VPS**
Upload your public SSH key to the default user on the VPS:

```bash
scp id_monvps.pub debian@<IP>:.ssh/id_monvps.pub
```

---

### 4. **Transfer the Setup Script to the VPS**
Copy the `setup_vps.sh` script to the VPS:

```bash
scp setup_vps.sh debian@<IP>:/home/debian
```

---

### 5. **Set Permissions for the Script**
Log in to your VPS and make the script executable:

```bash
ssh debian@<IP>
chmod +x setup_vps.sh
```

---

### 6. **Run the Setup Script**
Switch to the root user and execute the script:

```bash
sudo su -
./setup_vps.sh
```

---

### 7. **Clean Up Known Hosts**
On your local machine, remove the old SSH key fingerprint associated with the VPS:

```bash
ssh-keygen -R <IP>
```

---

## **Tips for a Smooth Setup**
- 🔧 Ensure your local machine has the necessary permissions to access the `.ssh` folder.
- 🔍 Always verify the IP address of your VPS before running any command.
- 🔐 Keep a backup of your SSH keys in a secure location.

---

## **License**
This setup guide is released under the [MIT License](https://opensource.org/licenses/MIT). Feel free to use, modify, and share it as needed.

---

## **Contact**
If you encounter any issues or have questions, feel free to reach out:
- 📧 **Email**: Mlucas44@outlook.fr
- 🐙 **GitHub**: [YourGitHubProfile](https://github.com/Mlucas44)

---

🎉 **Enjoy your new VPS setup!**

