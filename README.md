# Sindoh 3DWOX 1

This repository collects information on the [Sindoh 3DWOX
1](https://3dprinter.sindoh.com/en/product/3dwox1) 3D printer.

## Overview

The hardware is based on a Marvell `mv61x0` (88PA6110?); the CPU calls itself “PJ4B-MP ARMv7 rev 1
(v7l)”:

```
# cat /proc/cpuinfo
processor       : 0
BogoMIPS        : 789.70

processor       : 1
BogoMIPS        : 789.70

Features        : swp half fastmult vfp edsp neon vfpv3 tls
CPU implementer : 0x56
CPU architecture: 7
CPU variant     : 0x2
CPU part        : 0x584
CPU revision    : 1

Hardware        : mv61x0
Revision        : 0021
Serial          : 0000000000000000
```

The front panel display is accessible via `/dev/fb0`, handled by the `mv61fb` driver. The
[fbcat](https://github.com/jwilk/fbcat) utility works on it without any issues. The touch controller
is a Rohm BU21029GUL, exposed via `evdev` on `/dev/event0` (`/sys/devices/virtual/input/input0`).

Attached via USB are a “Marvell Wireless Device” (1286:2040, `usb8xxx.ko`?) and a “HD 720P Webcam”
(0c45:6341 `uvcvideo.ko`). The device itself exports a USB gadget; “Marvell 61x0 Printer Driver
2012”.

The mass storage device is a “mv61x0\_nand”; Linux is loaded via U-Boot and a serial console is
exposed with 115200 Baud, but I haven’t had the need yet to find it on the PCB.

## Printing stuff

All printing functionality (communication with the cartridge’s “security chip”, PJL and G-Code
parsing, the actual driving of the motor GPIOs, etc.) is handled by the
`/marvell_lspsdk_3dp_gemstone-debug_stripped.elf` binary. It listens on TCP port 9100 for print jobs
and on port 35345 for UI commands, although it rejects non-local connections for the latter.

The `/app/UIManager` binary communicates with the previous binary on port 35345. It starts
`appBrowser`, which communicates with `UIManager` via WebSocket on port 1337.

`/app/appBrowser` is a Qt application serving HTML pages from `/app/SVN_GUI/home.html`. It renders
to the Linux framebuffer `/dev/fb0` and is controlled via touch events from `/dev/event0`.

The `marvell_lspsdk_3dp_gemstone-debug_stripped.elf` uses [POSIX messages
queues](https://man7.org/linux/man-pages/man7/mq_overview.7.html) for inter-thread and inter-process
communication too. Persistent data is stored in a SQLite database at `/app/nvram/karas.db`.

## Misc

The web interface is served from `/test/web` by a lighttpd on port 80. The CGI scripts to e.g.
cancel a job access the `karas.db` SQLite database and communicate with
`marvell_lspsdk_3dp_gemstone-debug_stripped.elf` over the `/mq_ui_to_sys` message queue. There are
no non-root processes.

There’s an `mjpg_streamer` serving the webcam output on TCP port 8080, but it’s also opened the
`/mq_sys_to_cam` message queue, so it may do more. An snmpd is listening on UDP port 161, v1 RO
community is “public“.

## Root

tl;dr: Grab a firmware update from Sindoh and put `nc -llp 2323 -e /bin/sh` into
`_update_rodin_up/snapshot_version.sh`. Connect with `rlwrap -S'# ' nc $PRINTER 2323` or so.
**DO NOT** log in via telnet or ssh. The root filesystem is mounted and all
vendor binaries are started from `/etc/profile` (which presumably gets triggered by an auto-login on
ttyS0), so starting a login shell will cause a sort-of second boot, potentially destructing data
(read: brick your printer).

The `/app/auto_update.sh` will search for a `update.she` (encrypted shell script) on an inserted USB
stick in the `_update_rodin`, `_update_rodin_up` or `_update_rodin_eco` directory, depending on the
exact printer model. This shell script is decrypted from aes-256-cbc with the key (and IV == key)
stored in `/app/crypto_key.dat`, which is itself encrypted with aes-256-cbc; key and IV `SINDOH`.
The update encryption key and IV for the 3DWOX 1 is `sindoh024601779U`. Finally, the `.she` file is
expected to be a bzip2’ed tar archive that gets extracted to `/tmp`. See
[`pack_firmware.sh`](pack_firmware.sh) for an example.
