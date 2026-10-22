#!/usr/bin/env python3
"""Read-only Linux telemetry, locally or streamed over an existing SSH alias."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time


def read(path):
    try:
        return Path(path).read_text()
    except OSError:
        return ""


class Sampler:
    def __init__(self):
        self.previous_cpu = {}
        self.previous_net = None
        self.disks = []
        self.disk_time = -100
        self.cpu_name = next((line.split(":", 1)[1].strip() for line in read("/proc/cpuinfo").splitlines()
                              if line.startswith("model name")), "CPU")

    def sample(self):
        now = time.monotonic()
        cpus = {}
        for line in read("/proc/stat").splitlines():
            fields = line.split()
            if not fields or not fields[0].startswith("cpu"):
                continue
            values = list(map(int, fields[1:9]))  # guest time is already in user/nice
            if len(values) < 5:
                continue
            total, idle = sum(values), values[3] + values[4]
            before = self.previous_cpu.get(fields[0])
            result = {"usage": None, "user": 0, "system": 0}
            if before and total > before[0]:
                delta = total - before[0]
                result = {
                    "usage": max(0, min(1, 1 - (idle - before[1]) / delta)),
                    "user": max(0, (values[0] + values[1] - before[2]) / delta),
                    "system": max(0, (values[2] + sum(values[5:7]) - before[3]) / delta),
                }
            self.previous_cpu[fields[0]] = (total, idle, values[0] + values[1], values[2] + sum(values[5:7]))
            cpus[fields[0]] = result

        memory = {}
        for line in read("/proc/meminfo").splitlines():
            key, value = line.split(":", 1)
            memory[key] = int(value.split()[0]) * 1024
        total = memory.get("MemTotal", 0)
        available = min(total, memory.get("MemAvailable", memory.get("MemFree", 0)))
        free = memory.get("MemFree", 0)
        cache = max(0, memory.get("Cached", 0) + memory.get("SReclaimable", 0)
                    + memory.get("Buffers", 0) - memory.get("Shmem", 0))
        cache = min(cache, max(0, total - free))
        ram = {"total": total, "used": total - available, "available": available,
               "free": free, "cache": cache, "apps": max(0, total - free - cache)}
        swap_total = memory.get("SwapTotal", 0)

        interfaces = {}
        for line in read("/proc/net/dev").splitlines()[2:]:
            name, counters = line.split(":", 1)
            name, counters = name.strip(), counters.split()
            if name == "lo" or name.startswith(("veth", "docker", "br-", "virbr", "tun", "wg")):
                continue
            interfaces[name] = (int(counters[0]), int(counters[8]))
        received = sent = 0
        if self.previous_net:
            elapsed, previous = now - self.previous_net[0], self.previous_net[1]
            if elapsed > 0:
                for name, counters in interfaces.items():
                    if name in previous:
                        received += max(0, counters[0] - previous[name][0]) / elapsed
                        sent += max(0, counters[1] - previous[name][1]) / elapsed
        net_ready = self.previous_net is not None
        self.previous_net = (now, interfaces)

        if now - self.disk_time >= 15:
            self.disks = self.sample_disks()
            self.disk_time = now
        cpu = cpus.get("cpu", {"usage": None, "user": 0, "system": 0})
        return {"timestamp": time.time(), "hostname": os.uname().nodename,
                "cpu": cpu["usage"], "cpuUser": cpu["user"], "cpuSystem": cpu["system"],
                "cores": [value["usage"] for key, value in cpus.items() if key != "cpu"],
                "cpuName": self.cpu_name, "load": list(os.getloadavg()),
                "uptime": float((read("/proc/uptime") or "0").split()[0]),
                "memory": ram, "swap": {"total": swap_total, "used": swap_total - memory.get("SwapFree", 0)},
                "disks": self.disks, "network": {"ready": net_ready, "received": received, "sent": sent,
                "interfaces": list(interfaces)}}

    @staticmethod
    def sample_disks():
        mounts = []
        for line in read("/proc/mounts").splitlines():
            fields = line.split()
            if len(fields) < 3 or fields[2] not in ("ext2", "ext3", "ext4", "xfs", "btrfs", "zfs", "bcachefs", "ntfs3"):
                continue
            mount = fields[1].replace("\\040", " ").replace("\\134", "\\")
            if mount != "/boot" and not mount.startswith("/boot/"):
                mounts.append((mount, fields[0]))
        mounts.sort(key=lambda entry: (entry[0] != "/", len(entry[0])))
        if not any(mount == "/" for mount, source in mounts):
            mounts.insert(0, ("/", "root"))
        disks, devices = [], set()
        for mount, source in mounts:
            try:
                # Btrfs subvolumes can have distinct st_dev but share capacity.
                device = os.path.realpath(source) if source.startswith("/dev/") else os.stat(mount).st_dev
                if device in devices:
                    continue
                usage = shutil.disk_usage(mount)
                devices.add(device)
                disks.append({"mount": mount, "total": usage.total, "used": usage.used, "free": usage.free})
            except OSError:
                continue
        return disks[:16]


def remote(host, interval):
    # No remote files or services: python reads this same sampler from stdin.
    child = subprocess.Popen(["ssh", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5",
                              "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=1",
                              host, "python3", "-u", "-", "--interval", str(interval)],
                             stdin=subprocess.PIPE)
    def stop(signum, frame):
        child.terminate()
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, stop)
    try:
        child.communicate(Path(__file__).read_bytes())
        return child.returncode
    finally:
        if child.poll() is None:
            child.terminate()
            child.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="")
    parser.add_argument("--interval", type=float, default=2)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    if args.host:
        if args.host.startswith("-") or not all(c.isalnum() or c in "._-" for c in args.host):
            parser.error("host must be an SSH alias")
        return remote(args.host, max(1, args.interval))
    sampler = Sampler()
    while True:
        print(json.dumps(sampler.sample(), separators=(",", ":")), flush=True)
        if args.once:
            return 0
        time.sleep(max(1, args.interval))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (BrokenPipeError, KeyboardInterrupt):
        sys.exit(0)
