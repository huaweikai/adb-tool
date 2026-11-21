import asyncio
from pathlib import Path
import posixpath
import sys
import tempfile
import types
import unittest
from unittest.mock import AsyncMock, patch

import pymobiledevice3_cli as cli


class CrashDispatchTests(unittest.TestCase):
    def test_daemon_download_reaches_crash_pull(self):
        pull = AsyncMock()
        with patch.object(cli, "_fast_crash_pull", pull):
            asyncio.run(cli._dispatch_daemon_cmd(
                ["crash", "pull", "--udid", "phone", "/tmp/out", "/app.ips"]
            ))
        pull.assert_awaited_once_with("phone", "/tmp/out", "/app.ips")

    def test_one_shot_download_reaches_crash_pull(self):
        pull = AsyncMock()
        args = ["cli", "crash", "pull", "--udid", "phone", "/tmp/out", "/app.ips"]
        with patch.object(cli, "_fast_crash_pull", pull), patch.object(sys, "argv", args):
            self.assertTrue(cli._fast_path())
        pull.assert_awaited_once_with("phone", "/tmp/out", "/app.ips")


class PcapDispatchTests(unittest.TestCase):
    def test_daemon_dispatch_pcap_start(self):
        start = AsyncMock()
        with patch.object(cli, "_fast_pcap_start", start):
            asyncio.run(cli._dispatch_daemon_cmd(
                ["adb-tool-ios", "pcap-start", "--udid", "phone-1", "/tmp/cap.pcapng", "Safari", "en0"]
            ))
        start.assert_awaited_once_with("phone-1", "/tmp/cap.pcapng", process="Safari", interface="en0")

    def test_daemon_dispatch_pcap_status(self):
        status = AsyncMock()
        with patch.object(cli, "_fast_pcap_status", status):
            asyncio.run(cli._dispatch_daemon_cmd(
                ["adb-tool-ios", "pcap-status", "--udid", "phone-1"]
            ))
        status.assert_awaited_once_with("phone-1")

    def test_daemon_dispatch_pcap_stop(self):
        stop = AsyncMock()
        with patch.object(cli, "_fast_pcap_stop", stop):
            asyncio.run(cli._dispatch_daemon_cmd(
                ["adb-tool-ios", "pcap-stop", "--udid", "phone-1"]
            ))
        stop.assert_awaited_once_with("phone-1")

    def test_one_shot_pcap_start(self):
        start = AsyncMock()
        args = ["cli", "adb-tool-ios", "pcap-start", "--udid", "phone-1", "/tmp/cap.pcapng"]
        with patch.object(cli, "_fast_pcap_start", start), patch.object(sys, "argv", args):
            self.assertTrue(cli._fast_path())
        start.assert_awaited_once_with("phone-1", "/tmp/cap.pcapng", process=None, interface=None)


class AfcTransferTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.lockdown = types.SimpleNamespace(close=AsyncMock())
        lockdown_module = types.ModuleType("pymobiledevice3.lockdown")
        lockdown_module.create_using_usbmux = AsyncMock(return_value=self.lockdown)
        proxy_module = types.ModuleType("pymobiledevice3.services.installation_proxy")
        proxy_module.InstallationProxyService = object
        afc_module = types.ModuleType("pymobiledevice3.services.afc")
        afc_module.AfcService = object
        house_module = types.ModuleType("pymobiledevice3.services.house_arrest")
        house_module.HouseArrestService = object
        modules = {
            "pymobiledevice3": types.ModuleType("pymobiledevice3"),
            "pymobiledevice3.lockdown": lockdown_module,
            "pymobiledevice3.services": types.ModuleType("pymobiledevice3.services"),
            "pymobiledevice3.services.installation_proxy": proxy_module,
            "pymobiledevice3.services.afc": afc_module,
            "pymobiledevice3.services.house_arrest": house_module,
        }
        self.module_patch = patch.dict(sys.modules, modules)
        self.module_patch.start()
        self.addCleanup(self.module_patch.stop)

    async def test_directory_pull_has_one_root_directory(self):
        # Simulate pymobiledevice3's real contract: directory pulls append
        # basename(source), while the backend passes a complete target path.
        for virtual_path, source_path in [
            ("/DCIM", "/DCIM"),
            ("/Apps/com.example/Documents", "/Documents"),
            ("/Apps/com.example", "/"),
        ]:
            with self.subTest(path=virtual_path), tempfile.TemporaryDirectory() as temp:
                target = Path(temp) / "download"

                async def pull(src, dst, **kwargs):
                    root = Path(dst) / posixpath.basename(src)
                    root.mkdir(parents=True, exist_ok=True)
                    (root / "content.txt").write_text("recorded content")

                afc = AsyncMock()
                afc.__aenter__.return_value = afc
                afc.isdir.return_value = True
                afc.pull.side_effect = pull
                with patch.object(cli, "_open_afc_for_path", AsyncMock(
                    return_value=(afc, "media", None, source_path)
                )):
                    await cli._fast_afc_op("phone", "pull", [virtual_path, str(target)])
                self.assertEqual((target / "content.txt").read_text(), "recorded content")
                self.assertEqual([p.name for p in target.iterdir()], ["content.txt"])

    async def test_file_pull_uses_exact_destination(self):
        afc = AsyncMock()
        afc.__aenter__.return_value = afc
        afc.isdir.return_value = False
        with patch.object(cli, "_open_afc_for_path", AsyncMock(
            return_value=(afc, "media", None, "/notes.txt")
        )):
            await cli._fast_afc_op("phone", "pull", ["/notes.txt", "/tmp/target"])
        afc.pull.assert_awaited_once_with("/notes.txt", "/tmp/target", progress_bar=False)

    async def test_virtual_apps_root_cannot_open_media_root(self):
        with self.assertRaisesRegex(ValueError, "virtual directory"):
            await cli._open_afc_for_path(self.lockdown, "/Apps")

    async def test_cross_container_move_is_rejected(self):
        with patch.object(cli, "_open_afc_for_path", AsyncMock()) as open_afc:
            with self.assertRaisesRegex(ValueError, "different iOS containers"):
                await cli._fast_afc_op("phone", "mv", [
                    "/Apps/com.first/Documents/file.txt",
                    "/Apps/com.second/Documents/file.txt",
                ])
            open_afc.assert_not_awaited()
        self.lockdown.close.assert_awaited_once()


if __name__ == "__main__":
    unittest.main()
