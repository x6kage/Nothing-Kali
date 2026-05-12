# Security & Operational Considerations

Important safety, legal, and operational security guidance for using NetHunter on Nothing phones.

## Legal Disclaimer

**Penetration testing without explicit written authorization is illegal in most jurisdictions.** The tools provided by NetHunter Pro (Metasploit, aircrack-ng, etc.) can be used for both legitimate security testing and malicious attacks. You are solely responsible for how you use these tools.

### When It's Legal

- Testing your own networks and devices
- Authorized penetration testing with written scope agreements
- Security research in controlled lab environments
- Capture-the-flag (CTF) competitions
- Educational exercises on isolated networks

### When It's Illegal

- Accessing networks without owner permission
- Capturing packets on networks you don't own or have authorization for
- Deauthentication attacks on public/third-party networks
- Any unauthorized access to computer systems

## Device Security After Modification

### What Changes in Your Security Posture

Flashing a custom kernel and rooting your device changes its security model:

| Aspect | Stock | After Modification |
|--------|-------|--------------------|
| Bootloader | Locked | Unlocked (required) |
| Root access | None | Full (Magisk/KernelSU) |
| Verified boot | Enforced | Bypassed |
| OTA updates | Automatic | Manual / broken |
| SafetyNet/Play Integrity | Passes | May fail |
| Kernel integrity | Verified | Custom (unverified) |
| SELinux | Enforcing | May be set to permissive |

### Mitigations

**Keep root access controlled:**

- Magisk: Enable DenyList for banking/payment apps
- KernelSU: Use the allowlist to restrict which apps can request root
- Don't grant root to untrusted apps

**Keep the device updated:**

- Custom kernels break OTA. To update Nothing OS:
  1. Restore stock kernel
  2. Apply OTA
  3. Re-flash custom kernel
- Monitor [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware) for security patches

**Protect fastboot access:**

- Anyone with physical access + fastboot can flash your device
- Don't leave the device unattended in bootloader mode
- Consider re-locking the bootloader when not pentesting (note: this wipes data)

## Operational Security (OpSec)

### WiFi Monitoring Considerations

When using monitor mode, your device's WiFi MAC address is visible in the radio environment. This can be used to identify and locate you.

**MAC address randomization:**

```bash
# Change MAC before entering monitor mode
ip link set wlan0 down
macchanger -r wlan0       # random MAC
# or
macchanger -m XX:XX:XX:XX:XX:XX wlan0   # specific MAC
ip link set wlan0 up
```

> **Note:** `macchanger` may not work with all WiFi drivers. For ath12k, the MAC change must happen while the interface is down.

**Minimize radio footprint:**

- Only enable monitor mode when actively testing
- Switch back to managed mode when done
- Power off external WiFi adapters when not in use

### USB HID Attack Considerations

USB HID attacks (DuckyScript, keyboard emulation) are executed via physical USB connection. Be aware:

- The target machine logs USB device connections (Windows Event Log, macOS system.log)
- USB device descriptors (VID/PID) identify the phone model
- Some endpoint protection software detects rapid keystroke injection

### Network Attack Considerations

When using Metasploit, Nmap, or other network tools from the phone:

- Your phone's IP address is visible on the target network
- Use a VPN or proxy when testing remote targets
- ARP and routing table entries will show your device
- Aggressive scanning can trigger IDS/IPS alerts

## Data Protection

### Sensitive Data on the Device

NetHunter usage may create sensitive data:

| Data Type | Location | Risk |
|-----------|----------|------|
| Captured packets (.pcap) | `/sdcard/` or chroot | Contains network traffic |
| Cracked passwords | Chroot / tool output | Credential exposure |
| Metasploit session logs | `~/.msf4/` in chroot | Attack details |
| SSH keys | `~/.ssh/` in chroot | Remote access credentials |
| WiFi handshakes | Tool output directories | Can reveal network passwords |

### Cleanup After Testing

```bash
# Securely delete capture files
su
shred -u /sdcard/capture*.pcap

# Clean Metasploit logs
rm -rf /data/local/nhsystem/kali-arm64/root/.msf4/logs/*

# Clear command history
history -c
rm ~/.bash_history ~/.zsh_history 2>/dev/null

# Clear WiFi handshakes
rm -f /data/local/nhsystem/kali-arm64/root/*.cap
rm -f /data/local/nhsystem/kali-arm64/root/*.hccapx
```

### Encryption

- Enable Android full-disk encryption (enabled by default on Nothing phones)
- Use encrypted volumes for storing sensitive pentest data:
  ```bash
  # Create encrypted container in chroot
  dd if=/dev/urandom of=/root/pentest_data.img bs=1M count=500
  cryptsetup luksFormat /root/pentest_data.img
  cryptsetup open /root/pentest_data.img pentest_data
  mkfs.ext4 /dev/mapper/pentest_data
  mount /dev/mapper/pentest_data /root/pentest/
  ```

## Network Isolation for Testing

### Setting Up an Isolated Test Network

For safe practice and testing:

1. **Dedicated access point:** Use a separate WiFi router not connected to the internet
2. **Test devices:** Old phones, laptops, or VMs as targets
3. **No production networks:** Never test on networks with real users/data
4. **Document everything:** Keep logs of all tests for reports

### VPN Setup for Remote Testing

If testing remote targets (with authorization):

```bash
# Install OpenVPN in chroot
apt install -y openvpn

# Connect to VPN
openvpn --config /path/to/client.ovpn

# Verify traffic goes through VPN
curl ifconfig.me
```

## Responsible Disclosure

If your testing reveals vulnerabilities in third-party systems (with authorization):

1. **Document the vulnerability** clearly with reproduction steps
2. **Report privately** to the system owner before disclosing publicly
3. **Follow the organization's responsible disclosure policy** if one exists
4. **Allow reasonable time** for the fix before public disclosure (90 days is standard)

## Emergency Procedures

### If Your Device Is Lost or Stolen

A rooted device with NetHunter is a powerful tool in the wrong hands:

1. **Remote wipe** via Android Device Manager / Google Find My Device
2. **Revoke any SSH keys** stored on the device
3. **Change passwords** for any services whose credentials are on the device
4. **Notify** relevant parties if pentest data for clients was on the device

### If You Accidentally Attack the Wrong Target

1. **Stop immediately** — kill all running tools
2. **Document** exactly what happened (timestamps, tools used, scope)
3. **Notify** the network owner if you've caused any disruption
4. **Consult legal counsel** if there's any question about authorization
