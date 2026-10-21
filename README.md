# Baikal Appliance

A Baikal CalDAV/CardDAV appliance based on Alpine Linux and distributed as a QCOW2 disk image. It can be imported into Proxmox VE or another virtualization platform that supports QCOW2.

## Features

- Nginx, PHP-FPM, and Baikal
- Avahi mDNS, accessible at `baikal.local` (client networks must support mDNS)
- QEMU Guest Agent

## Use the Prebuilt Image

These instructions assume that you have obtained `baikal-appliance-v0.13.0.qcow2`. To build the image yourself, see [Build from Source](#build-from-source).

To import the image into Proxmox VE:

- Create a VM and note its VM ID. A VirtIO network interface connected to an internet-enabled bridge is recommended.
- Upload the image to the Proxmox host and run the following command, replacing the VM ID, image path, and storage name:

```sh
qm importdisk <VMID> baikal-appliance-v0.13.0.qcow2 <STORAGE>
```

- In the VM's Hardware settings, add the imported Unused Disk and configure the boot order. Enable QEMU Guest Agent in the Options settings.
- Start the VM, log in through the console, and complete the initial setup.

The image includes QEMU Guest Agent and enables it at boot. You must also enable the agent in the VM's Proxmox VE options.

## Initial Setup

- System account: `root`
- Default password: empty

The image has an empty default root password. Use it only in an isolated environment for initial setup. After logging in, immediately set a strong password by running `passwd`. Do not expose the VM to untrusted networks until you have secured access. The installation script does not install or enable SSH, so use the virtualization platform's console.

Once the VM has an IP address, open `http://<VM-IP>/` in a browser to complete Baikal's initial setup. The default hostname is `baikal`; if the client network supports mDNS, you can also use `http://baikal.local/`.

## Build from Source

To build the image yourself, follow the [VM creation guide](docs/create_vm.md). In the Alpine Linux VM, run the installation script as root:

```sh
sh /mnt/shared/full_install.sh
```

You can optionally choose a custom VM hostname. On networks that support mDNS, the VM will typically be reachable at `<hostname>.local`:

```sh
BAIKAL_HOSTNAME=calendar sh /mnt/shared/full_install.sh
```

By default, the installation script downloads Baikal version `0.13.0` from the official Baikal GitHub Releases and configures Nginx, PHP-FPM, Avahi, and QEMU Guest Agent. After the build, open the VM's IP address or hostname in a browser to complete Baikal's initial setup.

For day-to-day administration, SSH setup, and manual installation, see [Install and Manage Baikal](docs/manage_baikal.md).

`scripts/clean.sh` is only for cleaning the VM before creating an image. It removes temporary files and logs, fills the remaining free disk space, and then shuts down the VM. It also stops services; do not run it on a VM in regular use.

## Upstream Projects and Acknowledgments

This project uses and acknowledges the following upstream projects, their maintainers, and contributors:

- [Alpine Linux](https://www.alpinelinux.org/): the Linux distribution used by this appliance. Package information is available in the [official package index](https://pkgs.alpinelinux.org/), and package build recipes are available in the [Alpine aports repository](https://gitlab.alpinelinux.org/alpine/aports).
- [Baïkal](https://github.com/sabre-io/Baikal): a CalDAV/CardDAV server maintained by sabre-io. This project installs Baïkal 0.13.0. See the [Baïkal source repository](https://github.com/sabre-io/Baikal) and the [0.13.0 release page](https://github.com/sabre-io/Baikal/releases/tag/0.13.0) for source code and release files.

This project is responsible for integrating and configuring the appliance. Upstream software remains the property of its respective authors and maintainers and is distributed under its own license. This project is not affiliated with the Alpine Linux or Baïkal maintainers. When redistributing an image that includes upstream software, make sure to comply with the applicable licenses and notice requirements for each component.

## License

This repository includes the GNU General Public License, version 3. See [LICENSE](LICENSE). Before distributing an image that includes Baikal, Alpine Linux, or other packages, also verify and include the applicable licenses and notices for those upstream components.
