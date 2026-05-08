# Fedora Package Reference

This guide follows the style conventions from the RHEL Workstation Builder project.

## Package Naming Conventions

Fedora packages follow specific naming patterns that differ from other distributions.

### Python Packages

```yaml
# Fedora package names for Python
# Use these in dnf tasks:
# - name: Install Python packages
#   ansible.builtin.dnf:
#     name: ["{{ python_packages }}"]
#     state: present
#   become: true
#   tags: ["python", "packages"]

python3:                 # Python 3 interpreter
python3-devel:           # Python 3 development headers
python3-pip:             # pip for Python 3
python3-venv:            # venv module for Python 3
python3-setuptools:
python3-wheel:
python3-virtualenv:

# Python libraries (prefixed with python3-)
python3-requests:
python3-flask:
python3-django:
python3-numpy:
python3-pandas:
python3-jinja2:
python3-yaml:

# Virtual environments
python3.11:             # Specific Python version
python3.11-devel:
python3.11-pip:
python3.11-venv:
```

### Development Tools

```yaml
# Build tools
gcc:
gcc-c++:
make:
cmake:
autoconf:
automake:
libtool:

# Version control
git:
mercurial:
subversion:

# Utilities
curl:
wget:
rsync:
tree:
htop:
iotop:
nmon:
tmux:
screen:

# Editors
vim:
emacs:
nano:
micro:
```

### Terminal & Shell

```yaml
# Terminal emulators
kitty:
alacritty:
xfce4-terminal:
konsole:
gnome-terminal:

# Shells
bash:
zsh:
fish:
tcsh:

# Terminal multiplexers
tmux:
screen:

# Terminal utilities
ranger:               # File manager
fzf:                  # Fuzzy finder
bat:                  # cat replacement
exa:                  # ls replacement
fd-find:             # find replacement
ripgrep:              # grep replacement

# Zsh plugins
zsh-syntax-highlighting:
zsh-autosuggestions:
```

### Multimedia

```yaml
# Audio/Video
ffmpeg:
ffmpeg-freeworld:
vlc:
mpv:
mplayer:

# Audio only
mpg123:
sox:

# Streaming
obs-studio:
streamlink:

# Codecs
gstreamer1:
gstreamer1-plugins-base:
gstreamer1-plugins-good:
gstreamer1-plugins-bad:
gstreamer1-plugins-ugly:
gstreamer1-libav:
```

### System Utilities

```yaml
# System monitoring
htop:
iotop:
nmon:
glances:
netdata:
prometheus:
grafana:

# Process management
systemd:
procps-ng:
psmisc:
sysstat:

# Network utilities
net-tools:
iproute:
iputils:
bind-utils:
dnsutils:
nmap:
tcpdump:
wireshark:

# Security
openssh:
openssh-server:
openssh-clients:
fail2ban:
ufw:
firewalld:
clamtk:
rkhunter:
lynis:

# Disk utilities
ncdu:
parted:
gparted:
testdisk:
photorec:
e2fsprogs:
ntfs-3g:

# Archive utilities
tar:
gzip:
bzip2:
xz:
zip:
unzip:
p7zip:
p7zip-plugins:

# Filesystem
fuse:
sshfs:
nfs-utils:
cifs-utils:
```

### Container & Virtualization

```yaml
# Docker
docker:
docker-ce:
docker-ce-cli:
containerd.io:
runc:
docker-compose:
podman:
buildah:
skopeo:

# Virtualization
qemu:
libvirt:
virt-manager:
virt-viewer:

# Container orchestration
kubernetes:
kubectl:
minikube:
helm:
```

### Network & Servers

```yaml
# Web servers
nginx:
apache:
lighttpd:
caddy:

# Database servers
postgresql-server:
mariadb-server:
mysql-server:
redis:
memcached:
mongodb:

# Proxy/Cache
squid:
varnish:
haproxy:

# DNS
bind:
dnsmasq:

# Mail
postfix:
dovecot:

# FTP
vsftpd:
proftpd:

# SSH
openssh-server:

# VPN
openvpn:
wireguard-tools:
```

### Development Libraries

```yaml
# C/C++
glibc-devel:
libstdc++-devel:
libgcc:
libgomp:

# Python development
python3-devel:
python3-cryptography:

# OpenSSL
openssl:
openssl-devel:
libopenssl-devel:

# Database clients
postgresql:
postgresql-devel:
mariadb:
mariadb-devel:
mysql:
redis:
memcached:

# Web development
nodejs:
npm:

# Ruby
ruby:
ruby-devel:
rubygems:

# Go
golang:
golang-bin:

# Rust
rust:
cargo:

# Java
java-latest-openjdk:
java-latest-openjdk-devel:
maven:
```

### Package Groups

Fedora uses package groups for installing sets of related packages:

```yaml
# Install package group
- name: Install GNOME desktop group
  ansible.builtin.dnf:
    name: "@gnome-desktop"
    state: present
  become: true
  tags: ["desktop", "packages"]

# Common package groups
@core:
@minimal:
@standard:
@workstation-product:
@server-product:
@kde-desktop:
@xfce-desktop:
@cinnamon-desktop:
@mate-desktop:
@lxde-desktop:
@lxqt-desktop:
@development-tools:
@c-development:
@python-development:
@web-development:
@java-development:
```

### Repository Management

```yaml
# Enable RPM Fusion
- name: Enable RPM Fusion free
  ansible.builtin.dnf:
    name: https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-{{ ansible_distribution_version }}.noarch.rpm
    state: present
  become: true
  tags: ["repos", "rpmfusion"]

- name: Enable RPM Fusion nonfree
  ansible.builtin.dnf:
    name: https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-{{ ansible_distribution_version }}.noarch.rpm
    state: present
  become: true
  tags: ["repos", "rpmfusion"]

# Add third-party repository
- name: Add repository
  ansible.builtin.yum_repository:
    name: my-repo
    description: My Repository
    baseurl: https://example.com/repo
    gpgcheck: true
    gpgkey: https://example.com/repo/key.gpg
    enabled: true
  become: true
  tags: ["repos"]
```

### Package Management Tasks

```yaml
# Clean cache
- name: Clean dnf cache
  ansible.builtin.command: dnf clean all
  args:
    removes: /var/cache/dnf
  changed_when: false
  become: true
  tags: ["cleanup"]

# Update all packages
- name: Update all packages
  ansible.builtin.dnf:
    name: "*"
    state: latest
    update_cache: true
  become: true
  tags: ["upgrade"]

# Remove orphaned packages
- name: Remove orphaned packages
  ansible.builtin.command: dnf autoremove
  changed_when: false
  become: true
  tags: ["cleanup"]
```
