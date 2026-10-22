"""Telemetry accounting and rate regressions (no desktop or SSH required)."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[3] / 'dots/.config/quickshell/ii/scripts/system-stats.py'
spec = importlib.util.spec_from_file_location('system_stats', SCRIPT)
stats = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stats)


class TelemetryTests(unittest.TestCase):
    def sample(self, sampler, cpu, network, clock):
        files = {
            '/proc/stat': cpu,
            '/proc/meminfo': 'MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 400 kB\nCached: 200 kB\nSReclaimable: 50 kB\nBuffers: 50 kB\nShmem: 20 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n',
            '/proc/net/dev': 'header\nheader\n' + network,
            '/proc/uptime': '1000 2000',
        }
        with patch.object(stats, 'read', side_effect=lambda p: files.get(p, '')), \
             patch.object(stats.time, 'monotonic', return_value=clock), \
             patch.object(sampler, 'sample_disks', return_value=[]):
            return sampler.sample()

    def test_cpu_excludes_iowait_and_does_not_double_count_guest(self):
        sampler = stats.Sampler()
        first = self.sample(sampler, 'cpu 100 0 100 600 100 0 0 0 50 0', '', 1)
        self.assertIsNone(first['cpu'])
        sample = self.sample(sampler, 'cpu 120 0 110 640 130 0 0 0 60 0', '', 2)
        self.assertAlmostEqual(sample['cpu'], .3)
        self.assertAlmostEqual(sample['cpuUser'], .2)
        self.assertAlmostEqual(sample['cpuSystem'], .1)

    def test_memory_available_is_not_just_free_and_zero_swap_is_valid(self):
        sample = self.sample(stats.Sampler(), 'cpu 1 0 0 1 0 0 0 0', '', 1)
        ram = sample['memory']
        self.assertEqual(ram['used'], 600 * 1024)
        self.assertEqual(ram['available'], 400 * 1024)
        self.assertEqual(ram['apps'] + ram['cache'] + ram['free'], ram['total'])
        self.assertEqual(sample['swap'], {'used': 0, 'total': 0})

    def test_network_rates_use_elapsed_time_and_ignore_virtual_duplicates(self):
        sampler = stats.Sampler()
        def counters(rx, tx):
            return f'eth0: {rx} 0 0 0 0 0 0 0 {tx} 0 0 0 0 0 0 0\nlo: 999999 0 0 0 0 0 0 0 999999 0 0 0 0 0 0 0\nveth123: 999999 0 0 0 0 0 0 0 999999 0 0 0 0 0 0 0\n'
        self.sample(sampler, '', counters(100, 200), 1)
        sample = self.sample(sampler, '', counters(500, 1000), 3)
        self.assertEqual(sample['network']['received'], 200)
        self.assertEqual(sample['network']['sent'], 400)
        self.assertEqual(sample['network']['interfaces'], ['eth0'])
        reset = self.sample(sampler, '', counters(0, 0), 4)
        self.assertEqual(reset['network']['received'], 0)
        self.assertEqual(reset['network']['sent'], 0)

    def test_btrfs_subvolumes_share_one_capacity_meter(self):
        mounts = '/dev/test / btrfs rw 0 0\n/dev/test /home btrfs rw 0 0\n/dev/test /var/log btrfs rw 0 0\n'
        usage = type('Usage', (), {'total': 1000, 'used': 600, 'free': 400})()
        with patch.object(stats, 'read', return_value=mounts), \
             patch.object(stats.os, 'stat'), patch.object(stats.os.path, 'realpath', side_effect=lambda x: x), \
             patch.object(stats.shutil, 'disk_usage', return_value=usage):
            self.assertEqual(stats.Sampler.sample_disks(), [{'mount': '/', 'total': 1000, 'used': 600, 'free': 400}])


if __name__ == '__main__':
    unittest.main()
