#!/bin/sh

url="https://download.foldingathome.org/releases/public/release/fahclient/centos-6.7-64bit/v7.5"
fahclient_rpm="fahclient-7.5.1-1.x86_64.rpm"

wrapper()
{
cat << WRAPPER_END
#!/bin/sh

if [ ! -d \${HOME}/.fah ]; then
	mkdir \${HOME}/.fah || exit 1
fi
cd \${HOME}/.fah && /usr/bin/nice -n 20 /compat/linux/usr/bin/FAHClient
WRAPPER_END
}

linproc_entry()
{
cat << LINPROC_END
linproc         /compat/linux/proc     linprocfs        rw      0       0
LINPROC_END
}

linsysfs_entry()
{
cat << LINSYSFS_END
linsysfs        /compat/linux/sys      linsysfs         rw      0       0
LINSYSFS_END
}

if [ $(whoami) != "root" ]; then
	echo "You must be root to run this script" >&2
	exit 1
fi

if ! (kldstat | grep -q linux64); then
	kldload linux64
fi

if ! pkg info --exists emulators/linux_base-c7; then
	pkg install -y emulators/linux_base-c7
fi
if ! pkg info --exists archivers/rpm4; then
	pkg install -y archivers/rpm4
fi

if ! grep -wq '^linproc' /etc/fstab; then
	if [ ! -f /etc/fstab.bak.$$ ]; then
		cp /etc/fstab /etc/fstab.bak.$$
	fi
	linproc_entry >> /etc/fstab
	mkdir /compat/linux/proc 2>/dev/null
	if ! mount | grep -wq '^linprocfs'; then
		mount /compat/linux/proc
	fi
fi
if ! grep -wq '^linsysfs' /etc/fstab; then
	if [ ! -f /etc/fstab.bak.$$ ]; then
		cp /etc/fstab /etc/fstab.bak.$$
	fi
	linsysfs_entry >> /etc/fstab
	mkdir /compat/linux/sys 2>/dev/null
	if ! mount | grep -wq '^linsysfs'; then
		mount /compat/linux/sys
	fi
fi

sysrc "kld_list+=linux64"

fetch -o "/tmp/${fahclient_rpm}" "${url}/${fahclient_rpm}"

(cd /compat/linux && rpm2cpio < "/tmp/${fahclient_rpm}" | cpio -ivd) || exit 1

brandelf -t Linux /compat/linux/usr/bin/FAHClient

wrapper > /usr/local/bin/fah-wrapper
chmod a+x /usr/local/bin/fah-wrapper

