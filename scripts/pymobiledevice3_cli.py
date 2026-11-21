import asyncio
import datetime
import io
import json
from multiprocessing import freeze_support
import os
from pathlib import Path
import posixpath
import shutil
import tempfile
import time
import sys
from typing import Any, Optional


_rsd_cache: dict[str, Any] = {}
_rsd_locks: dict[str, asyncio.Lock] = {}
_prewarm_tasks: dict[str, asyncio.Task] = {}
_pcap_sessions: dict[str, dict[str, Any]] = {}
_pcap_locks: dict[str, asyncio.Lock] = {}


async def _resolve_rsd(udid: str):
    import platform
    from pymobiledevice3.exceptions import UserspaceTunnelUnavailableError
    from pymobiledevice3.remote import userspace_tunnel

    is_root = hasattr(os, "geteuid") and os.geteuid() == 0
    if platform.system() == "Darwin" and is_root:
        try:
            from pymobiledevice3.remote import native_tunnel

            return await native_tunnel.establish_native_rsd(serial=udid)
        except Exception:
            pass
    try:
        return await userspace_tunnel.establish_userspace_rsd(serial=udid, remotepairing_fallback=False)
    except UserspaceTunnelUnavailableError:
        if platform.system() == "Darwin":
            from pymobiledevice3.remote import native_tunnel

            return await native_tunnel.establish_native_rsd(serial=udid)
        raise


async def _get_cached_rsd(udid: str, force_new: bool = False):
    lock = _rsd_locks.setdefault(udid, asyncio.Lock())
    async with lock:
        if force_new:
            try:
                from pymobiledevice3.remote import userspace_tunnel

                if userspace_tunnel._cli_tunnel is not None:
                    try:
                        await userspace_tunnel._cli_tunnel.aclose()
                    except Exception:
                        pass
                    userspace_tunnel._cli_tunnel = None
            except Exception:
                pass
            if udid in _rsd_cache:
                old = _rsd_cache.pop(udid, None)
                if old is not None:
                    try:
                        await old.close()
                    except Exception:
                        pass
        if udid in _rsd_cache:
            return _rsd_cache[udid]
        rsd = await _resolve_rsd(udid)
        _rsd_cache[udid] = rsd
        return rsd


async def _prewarm_rsd(udid: str) -> None:
    try:
        await _get_cached_rsd(udid)
    except Exception:
        pass


async def _fast_usbmux_list(prewarm: bool = False) -> None:
    from pymobiledevice3 import usbmux
    from pymobiledevice3.lockdown import create_using_usbmux

    connected_devices = []
    seen_udids: set[str] = set()
    for device in await usbmux.list_devices():
        lockdown = await create_using_usbmux(
            device.serial,
            autopair=False,
            connection_type=device.connection_type,
        )
        info = lockdown.short_info
        connected_devices.append(info)
        udid = str(info.get("Identifier") or info.get("UniqueDeviceID") or device.serial or "")
        ver_str = str(info.get("ProductVersion") or "0")
        await lockdown.close()
        if udid:
            seen_udids.add(udid)
            try:
                major = int(ver_str.split(".")[0] or "0")
            except ValueError:
                major = 0
            if prewarm and major >= 17 and udid not in _rsd_cache:
                task = _prewarm_tasks.get(udid)
                if task is None or task.done():
                    _prewarm_tasks[udid] = asyncio.create_task(_prewarm_rsd(udid))
    if prewarm:
        for stale_udid in list(_rsd_cache.keys()):
            if stale_udid not in seen_udids:
                old = _rsd_cache.pop(stale_udid, None)
                if old is not None:
                    try:
                        await old.close()
                    except Exception:
                        pass
    print(json.dumps(connected_devices, indent=4, ensure_ascii=False))


async def _fast_crash_ls(udid: str) -> None:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.crash_reports import CrashReportsManager

    lockdown = await create_using_usbmux(serial=udid)
    try:
        async with CrashReportsManager(lockdown) as crash_manager:
            for path in await crash_manager.ls("/", 1):
                print(path)
    finally:
        await lockdown.close()


async def _fast_crash_pull(udid: str, out_dir: str, remote_file: str) -> None:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.crash_reports import CrashReportsManager

    lockdown = await create_using_usbmux(serial=udid)
    try:
        async with CrashReportsManager(lockdown) as crash_manager:
            await crash_manager.pull(out_dir, remote_file, False, None)
    finally:
        await lockdown.close()


async def _capture_with_rsd(rsd, out: Path) -> None:
    from pymobiledevice3.remote.core_device.screen_capture_service import ScreenCaptureService
    from pymobiledevice3.services.dvt.instruments.dvt_provider import DvtProvider
    from pymobiledevice3.services.dvt.instruments.screenshot import Screenshot

    try:
        async with ScreenCaptureService(rsd) as svc:
            resp = await svc.capture_screenshot()
            out.write_bytes(resp["image"])
            return
    except Exception:
        async with DvtProvider(rsd) as dvt, Screenshot(dvt) as shot:
            out.write_bytes(await shot.get_screenshot())


async def _fast_screenshot(udid: str, out_file: str, keep_rsd: bool = False) -> None:
    from pymobiledevice3.exceptions import InvalidServiceError, RSDRequiredError
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.dvt.instruments.dvt_provider import DvtProvider
    from pymobiledevice3.services.dvt.instruments.screenshot import Screenshot

    out = Path(out_file)
    if keep_rsd or udid in _rsd_cache:
        try:
            rsd = await _get_cached_rsd(udid)
            await _capture_with_rsd(rsd, out)
            return
        except Exception:
            try:
                rsd = await _get_cached_rsd(udid, force_new=True)
                await _capture_with_rsd(rsd, out)
                return
            except Exception:
                pass

    major = 0
    lockdown = await create_using_usbmux(serial=udid)
    try:
        try:
            major = int(str(lockdown.product_version or "0").split(".")[0] or "0")
        except ValueError:
            major = 0
        if major < 17:
            try:
                async with DvtProvider(lockdown) as dvt, Screenshot(dvt) as shot:
                    out.write_bytes(await shot.get_screenshot())
                    return
            except (InvalidServiceError, RSDRequiredError):
                pass
    finally:
        await lockdown.close()

    if keep_rsd:
        rsd = await _get_cached_rsd(udid, force_new=True)
        await _capture_with_rsd(rsd, out)
        return

    rsd = await _resolve_rsd(udid)
    try:
        await _capture_with_rsd(rsd, out)
    finally:
        await rsd.close()


async def _fast_status(udid: str) -> None:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.afc import AfcService
    from pymobiledevice3.services.diagnostics import DiagnosticsService

    status: dict[str, Any] = {
        "collectedAt": datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat(),
        "batteryLevel": "",
        "batteryStatus": "",
        "batteryTemperature": "",
        "cpuUsage": "",
        "cpuLoad": "",
        "memoryTotal": "",
        "memoryAvailable": "",
        "memoryUsedPercent": "",
        "storageTotal": "",
        "storageUsed": "",
        "storageAvailable": "",
        "storageUsedPercent": "",
        "resolution": "",
        "density": "",
        "refreshRate": "",
        "frameStats": "",
        "networkType": "",
        "wifiSsid": "",
        "wifiRssi": "",
        "mobileSignal": "",
        "ipAddress": "",
        "uptime": "",
        "thermalStatus": "Normal",
        "topProcesses": [],
    }

    lockdown = await create_using_usbmux(serial=udid)
    try:
        all_vals = lockdown.all_values or {}
        if all_vals.get("WiFiAddress"):
            status["networkType"] = "Wi-Fi"
        try:
            diag = DiagnosticsService(lockdown=lockdown)
            batt = await diag.get_battery()
            if isinstance(batt, dict):
                cap = batt.get("CurrentCapacity")
                if cap is not None:
                    status["batteryLevel"] = str(cap)
                if batt.get("FullyCharged"):
                    status["batteryStatus"] = "Full"
                elif batt.get("IsCharging"):
                    status["batteryStatus"] = "Charging"
                else:
                    status["batteryStatus"] = "Discharging"
                temp = batt.get("Temperature")
                if isinstance(temp, (int, float)) and temp > 0:
                    c_val = temp / 100.0 if temp > 200 else temp / 10.0
                    status["batteryTemperature"] = f"{c_val:.1f} ℃"
        except Exception:
            pass

        try:
            async with AfcService(lockdown=lockdown) as afc:
                dev_info = await afc.get_device_info()
                total_b = int(dev_info.get("st_totalbytes", 0))
                free_b = int(dev_info.get("st_freebytes", 0))
                if total_b > 0:
                    used_b = max(0, total_b - free_b)
                    status["storageTotal"] = f"{total_b / (1024**3):.1f} GB"
                    status["storageUsed"] = f"{used_b / (1024**3):.1f} GB"
                    status["storageAvailable"] = f"{free_b / (1024**3):.1f} GB"
                    status["storageUsedPercent"] = f"{(used_b / total_b) * 100:.1f}%"
        except Exception:
            pass
    finally:
        await lockdown.close()

    print(json.dumps(status, ensure_ascii=False))


async def _fast_props(udid: str) -> None:
    from pymobiledevice3.lockdown import create_using_usbmux

    lockdown = await create_using_usbmux(serial=udid)
    try:
        vals = lockdown.all_values or {}
        props: dict[str, str] = {}
        for k, v in vals.items():
            if isinstance(v, (str, int, float, bool)):
                props[str(k)] = str(v)
            elif isinstance(v, (list, dict)):
                try:
                    props[str(k)] = json.dumps(v, default=str, ensure_ascii=False)
                except Exception:
                    props[str(k)] = str(v)
        print(json.dumps(props, ensure_ascii=False))
    finally:
        await lockdown.close()


async def _fast_apps_list(udid: str) -> None:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    lockdown = await create_using_usbmux(serial=udid)
    try:
        apps = await InstallationProxyService(lockdown=lockdown).get_apps(application_type="User")
        pkgs = []
        for bundle_id, info in sorted(apps.items()):
            name = info.get("CFBundleDisplayName") or info.get("CFBundleName") or ""
            ver = info.get("CFBundleShortVersionString") or info.get("CFBundleVersion") or ""
            path = info.get("Path") or ""
            source_dir = f"{name} ({ver}) · {path}" if name else path
            pkgs.append({"packageName": bundle_id, "sourceDir": source_dir})
        print(json.dumps(pkgs, ensure_ascii=False))
    finally:
        await lockdown.close()


async def _fast_apps_uninstall(udid: str, bundle_id: str) -> None:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    lockdown = await create_using_usbmux(serial=udid)
    try:
        await InstallationProxyService(lockdown=lockdown).uninstall(bundle_id)
    finally:
        await lockdown.close()


async def _fast_apps_install(udid: str, pkg_path: str) -> None:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    lockdown = await create_using_usbmux(serial=udid)
    try:
        await InstallationProxyService(lockdown=lockdown).install_from_local(Path(pkg_path))
    finally:
        await lockdown.close()


async def _fast_clipboard_set(udid: str, text: str, keep_rsd: bool = False) -> None:
    from pymobiledevice3.remote.core_device.pasteboard_service import PasteboardService

    if keep_rsd or udid in _rsd_cache:
        try:
            rsd = await _get_cached_rsd(udid)
            async with PasteboardService(rsd) as pb:
                await pb.set_text(text)
            return
        except Exception:
            rsd = await _get_cached_rsd(udid, force_new=True)
            async with PasteboardService(rsd) as pb:
                await pb.set_text(text)
            return

    rsd = await _resolve_rsd(udid)
    try:
        async with PasteboardService(rsd) as pb:
            await pb.set_text(text)
    finally:
        await rsd.close()


def _format_afc_stat(name: str, full_path: str, st: dict[str, Any]) -> dict[str, Any]:
    ifmt = st.get("st_ifmt", "")
    is_dir = ifmt == "S_IFDIR"
    size = int(st.get("st_size", 0) or 0)
    mtime = st.get("st_mtime")
    if isinstance(mtime, datetime.datetime):
        modified = mtime.strftime("%Y-%m-%d %H:%M")
    else:
        modified = str(mtime or "")
    perms = "drwxr-xr-x" if is_dir else ("lrwxrwxrwx" if ifmt == "S_IFLNK" else "-rw-r--r--")
    return {
        "name": name,
        "path": full_path,
        "size": size,
        "isDir": is_dir,
        "permissions": perms,
        "modified": modified,
        "raw": json.dumps(st, default=str, ensure_ascii=False),
    }


def _parse_virtual_path(path: str) -> tuple[str, Optional[str], str]:
    norm = posixpath.normpath("/" + path.lstrip("/"))
    if norm in ("/", "/Media"):
        return ("media", None, "/" if norm == "/Media" else norm)
    if norm.startswith("/Media/"):
        return ("media", None, norm[len("/Media") :])
    if norm == "/Apps":
        return ("apps_root", None, "/")
    if norm.startswith("/Apps/"):
        rest = norm[len("/Apps/") :]
        parts = rest.split("/", 1)
        bundle_id = parts[0]
        sub = "/" + parts[1] if len(parts) > 1 else "/"
        return ("app", bundle_id, sub)
    return ("media", None, norm)


async def _open_afc_for_path(lockdown, path: str):
    from pymobiledevice3.services.afc import AfcService
    from pymobiledevice3.services.house_arrest import HouseArrestService

    kind, bundle_id, sub = _parse_virtual_path(path)
    if kind == "apps_root":
        raise ValueError("/Apps is a virtual directory, not an AFC path")
    if kind == "app" and bundle_id:
        svc = await HouseArrestService.create(lockdown=lockdown, bundle_id=bundle_id, documents_only=False)
        return svc, kind, bundle_id, sub
    return AfcService(lockdown=lockdown), kind, None, sub


async def _fast_afc_op(udid: str, op: str, args: list[str]) -> None:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    lockdown = await create_using_usbmux(serial=udid)
    try:
        if op == "ls":
            req_path = args[0]
            norm = posixpath.normpath("/" + req_path.lstrip("/"))
            if norm == "/Apps":
                apps = await InstallationProxyService(lockdown=lockdown).get_apps(application_type="User")
                entries = [
                    {
                        "name": bid,
                        "path": f"/Apps/{bid}",
                        "size": 0,
                        "isDir": True,
                        "permissions": "drwxr-xr-x",
                        "modified": "",
                    }
                    for bid in sorted(apps.keys())
                ]
                print(json.dumps(entries, ensure_ascii=False))
                return
            svc, _kind, _bid, sub = await _open_afc_for_path(lockdown, norm)
            async with svc as afc:
                names = await afc.listdir(sub)
                entries = []
                if norm == "/":
                    entries.append(
                        {
                            "name": "Apps",
                            "path": "/Apps",
                            "size": 0,
                            "isDir": True,
                            "permissions": "drwxr-xr-x",
                            "modified": "App Containers",
                        }
                    )
                for name in sorted(names):
                    child_sub = posixpath.join(sub, name)
                    child_virtual = posixpath.join(norm, name)
                    try:
                        st = await afc.stat(child_sub)
                        item = _format_afc_stat(name, child_virtual, st)
                        item.pop("raw", None)
                        entries.append(item)
                    except Exception:
                        entries.append(
                            {
                                "name": name,
                                "path": child_virtual,
                                "size": 0,
                                "isDir": False,
                                "permissions": "-rw-r--r--",
                                "modified": "",
                            }
                        )
                print(json.dumps(entries, ensure_ascii=False))
        elif op == "stat":
            req_path = args[0]
            norm = posixpath.normpath("/" + req_path.lstrip("/"))
            svc, _kind, _bid, sub = await _open_afc_for_path(lockdown, norm)
            async with svc as afc:
                st = await afc.stat(sub)
                print(json.dumps(_format_afc_stat(posixpath.basename(norm) or "/", norm, st), ensure_ascii=False))
        elif op == "cat":
            req_path = args[0]
            svc, _kind, _bid, sub = await _open_afc_for_path(lockdown, req_path)
            async with svc as afc:
                data = await afc.get_file_contents(sub)
                chunk = data[: 2 * 1024 * 1024]
                if hasattr(sys.stdout, "buffer"):
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                else:
                    sys.stdout.write(chunk.decode("utf-8", errors="replace"))
        elif op == "pull":
            req_path, local_dst = args[0], args[1]
            svc, _kind, _bid, sub = await _open_afc_for_path(lockdown, req_path)
            async with svc as afc:
                if await afc.isdir(sub):
                    # AFC appends the source directory name; the backend expects
                    # local_dst to be the directory itself, as with adb pull.
                    with tempfile.TemporaryDirectory(prefix="adb-tool-afc-") as staging:
                        await afc.pull(sub, staging, progress_bar=False)
                        source = Path(staging) / posixpath.basename(sub.rstrip("/"))
                        shutil.move(str(source), local_dst)
                else:
                    await afc.pull(sub, local_dst, progress_bar=False)
        elif op == "push":
            local_src, req_path = args[0], args[1]
            svc, _kind, _bid, sub = await _open_afc_for_path(lockdown, req_path)
            async with svc as afc:
                await afc.push(local_src, sub, progress_bar=False)
        elif op == "rm":
            req_path = args[0]
            svc, _kind, _bid, sub = await _open_afc_for_path(lockdown, req_path)
            async with svc as afc:
                await afc.rm(sub)
        elif op == "mv":
            src_path, dst_path = args[0], args[1]
            src_kind, src_bid, _ = _parse_virtual_path(src_path)
            dst_kind, dst_bid, sub_dst = _parse_virtual_path(dst_path)
            if (src_kind, src_bid) != (dst_kind, dst_bid) or src_kind == "apps_root":
                raise ValueError("Cannot move files between different iOS containers")
            svc, _kind, _bid, sub_src = await _open_afc_for_path(lockdown, src_path)
            async with svc as afc:
                await afc.rename(sub_src, sub_dst)
        elif op == "mkdir":
            req_path = args[0]
            svc, _kind, _bid, sub = await _open_afc_for_path(lockdown, req_path)
            async with svc as afc:
                await afc.makedirs(sub)
        elif op == "touch":
            req_path = args[0]
            svc, _kind, _bid, sub = await _open_afc_for_path(lockdown, req_path)
            async with svc as afc:
                await afc.set_file_contents(sub, b"")
    finally:
        await lockdown.close()


async def _fast_pcap_start(
    udid: str,
    out_file: str,
    process: Optional[str] = None,
    interface: Optional[str] = None,
) -> None:
    from pymobiledevice3 import usbmux
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.pcapd import PcapdService

    lock = _pcap_locks.setdefault(udid, asyncio.Lock())
    async with lock:
        session = _pcap_sessions.get(udid)
        if session and not session.get("stopped") and session.get("task") and not session["task"].done():
            f_path = session.get("file_path", out_file)
            f_size = os.path.getsize(f_path) if f_path and os.path.exists(f_path) else 0
            start_t = session.get("start_time", time.time())
            print(
                json.dumps(
                    {
                        "status": "capturing",
                        "active": True,
                        "filePath": f_path,
                        "packets": session.get("packets_count", 0),
                        "bytes": f_size,
                        "startTime": session.get("start_iso", ""),
                        "duration": round(time.time() - start_t, 1),
                        "process": session.get("process"),
                        "interface": session.get("interface"),
                    },
                    ensure_ascii=False,
                )
            )
            return

        out_path = Path(out_file).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)

        # 1. Verify that the device is actually connected via USB
        devices = await usbmux.list_devices()
        usb_device = next((d for d in devices if d.matches_udid(udid) and d.is_usb), None)
        if not usb_device:
            raise RuntimeError(
                "未检测到设备通过 USB 数据线连接。iOS 原生网络抓包受 Apple 安全策略限制，仅支持 USB 物理直连，请插紧数据线并解锁屏幕信任电脑。"
            )

        # 2. Connect strictly over USB
        lockdown = await create_using_usbmux(serial=udid, connection_type="USB")
        major = 0
        try:
            major = int(str(lockdown.product_version or "0").split(".")[0] or "0")
        except ValueError:
            major = 0

        provider = None
        lockdown_to_close = None
        svc = None

        if major < 17:
            provider = lockdown
            lockdown_to_close = lockdown
            svc = PcapdService(lockdown=provider)
        else:
            # On iOS 17+, attempt direct lockdown service first, then fallback to USB RSD tunnel
            try:
                candidate = PcapdService(lockdown=lockdown)
                await candidate.connect()
                provider = lockdown
                lockdown_to_close = lockdown
                svc = candidate
            except Exception:
                await lockdown.close()
                lockdown_to_close = None

                # Reset any cached userspace tunnel so it is guaranteed to establish a USB tunnel
                try:
                    from pymobiledevice3.remote import userspace_tunnel

                    if userspace_tunnel._cli_tunnel is not None:
                        try:
                            await userspace_tunnel._cli_tunnel.aclose()
                        except Exception:
                            pass
                        userspace_tunnel._cli_tunnel = None
                except Exception:
                    pass

                provider = await _get_cached_rsd(udid, force_new=True)
                svc = PcapdService(lockdown=provider)
                try:
                    await svc.connect()
                except Exception as exc:
                    err_str = str(exc)
                    if "USB only" in err_str or "ServiceProhibited" in err_str:
                        raise RuntimeError(
                            "iOS 系统拒绝启动网络抓包（Apple 安全限制：com.apple.pcapd 仅支持物理 USB 直连）。"
                            "请拔下 USB 数据线重新插紧，确保手机屏幕处于解锁状态并在提示时点击『信任此电脑』。"
                        ) from exc
                    raise

        out_handle = open(out_path, "wb")
        now_ts = time.time()
        now_iso = datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat()

        session = {
            "file_path": str(out_path),
            "file_handle": out_handle,
            "start_time": now_ts,
            "start_iso": now_iso,
            "packets_count": 0,
            "process": process,
            "interface": interface,
            "error": None,
            "stopped": False,
            "service": svc,
            "lockdown_to_close": lockdown_to_close,
        }

        async def _pcap_worker() -> None:
            async def _counting_gen(gen):
                async for packet in gen:
                    session["packets_count"] += 1
                    yield packet

            try:
                raw_gen = svc.watch(
                    packets_count=-1,
                    process=session["process"],
                    interface_name=session["interface"],
                )
                await svc.write_to_pcap(out_handle, _counting_gen(raw_gen))
            except asyncio.CancelledError:
                pass
            except Exception as exc:
                session["error"] = str(exc)
            finally:
                session["stopped"] = True
                if "end_time" not in session:
                    session["end_time"] = time.time()
                try:
                    out_handle.flush()
                    out_handle.close()
                except Exception:
                    pass
                try:
                    await svc.close()
                except Exception:
                    pass
                if session.get("lockdown_to_close"):
                    try:
                        await session["lockdown_to_close"].close()
                    except Exception:
                        pass

        session["task"] = asyncio.create_task(_pcap_worker())
        _pcap_sessions[udid] = session

        print(
            json.dumps(
                {
                    "status": "capturing",
                    "active": True,
                    "filePath": str(out_path),
                    "packets": 0,
                    "bytes": 0,
                    "startTime": now_iso,
                    "duration": 0.0,
                    "process": process,
                    "interface": interface,
                },
                ensure_ascii=False,
            )
        )


async def _fast_pcap_status(udid: str) -> None:
    session = _pcap_sessions.get(udid)
    if not session:
        print(
            json.dumps(
                {
                    "status": "idle",
                    "active": False,
                    "filePath": "",
                    "packets": 0,
                    "bytes": 0,
                    "duration": 0.0,
                    "startTime": "",
                    "process": None,
                    "interface": None,
                    "error": None,
                },
                ensure_ascii=False,
            )
        )
        return

    active = not session.get("stopped", False) and session.get("task") is not None and not session["task"].done()
    f_path = session.get("file_path", "")
    f_size = 0
    if f_path and os.path.exists(f_path):
        try:
            f_size = os.path.getsize(f_path)
        except Exception:
            pass

    start_t = session.get("start_time", time.time())
    if active:
        duration = max(0.0, time.time() - start_t)
    else:
        end_t = session.get("end_time", start_t)
        duration = max(0.0, end_t - start_t)

    print(
        json.dumps(
            {
                "status": "capturing" if active else "stopped",
                "active": active,
                "filePath": f_path,
                "packets": session.get("packets_count", 0),
                "bytes": f_size,
                "startTime": session.get("start_iso", ""),
                "duration": round(duration, 1),
                "process": session.get("process"),
                "interface": session.get("interface"),
                "error": session.get("error"),
            },
            ensure_ascii=False,
        )
    )


async def _fast_pcap_stop(udid: str) -> None:
    lock = _pcap_locks.setdefault(udid, asyncio.Lock())
    async with lock:
        session = _pcap_sessions.get(udid)
        if not session:
            print(
                json.dumps(
                    {
                        "status": "idle",
                        "active": False,
                        "filePath": "",
                        "packets": 0,
                        "bytes": 0,
                        "duration": 0.0,
                    },
                    ensure_ascii=False,
                )
            )
            return

        if not session.get("stopped"):
            session["stopped"] = True
            session["end_time"] = time.time()
            task = session.get("task")
            if task and not task.done():
                task.cancel()
                try:
                    await asyncio.wait_for(asyncio.shield(task), timeout=2.0)
                except Exception:
                    pass

        f_path = session.get("file_path", "")
        f_size = 0
        if f_path and os.path.exists(f_path):
            try:
                f_size = os.path.getsize(f_path)
            except Exception:
                pass

        start_t = session.get("start_time", time.time())
        end_t = session.get("end_time", time.time())
        duration = max(0.0, end_t - start_t)

        print(
            json.dumps(
                {
                    "status": "stopped",
                    "active": False,
                    "filePath": f_path,
                    "packets": session.get("packets_count", 0),
                    "bytes": f_size,
                    "startTime": session.get("start_iso", ""),
                    "duration": round(duration, 1),
                    "process": session.get("process"),
                    "interface": session.get("interface"),
                    "error": session.get("error"),
                },
                ensure_ascii=False,
            )
        )


async def _dispatch_daemon_cmd(cmd: list[str]) -> None:
    if cmd == ["usbmux", "list"]:
        await _fast_usbmux_list(prewarm=True)
        return
    if len(cmd) == 4 and cmd[:3] == ["crash", "ls", "--udid"]:
        await _fast_crash_ls(cmd[3])
        return
    if len(cmd) == 6 and cmd[:3] == ["crash", "pull", "--udid"]:
        await _fast_crash_pull(cmd[3], cmd[4], cmd[5])
        return
    if len(cmd) == 6 and cmd[:4] == ["developer", "dvt", "screenshot", "--udid"]:
        await _fast_screenshot(cmd[4], cmd[5], keep_rsd=True)
        return
    if len(cmd) == 5 and cmd[:3] == ["developer", "screenshot", "--udid"]:
        await _fast_screenshot(cmd[3], cmd[4], keep_rsd=True)
        return
    if len(cmd) >= 4 and cmd[0] == "adb-tool-ios" and cmd[2] == "--udid":
        op = cmd[1]
        udid = cmd[3]
        rest = cmd[4:]
        if op == "status":
            await _fast_status(udid)
            return
        if op == "props":
            await _fast_props(udid)
            return
        if op == "apps-list":
            await _fast_apps_list(udid)
            return
        if op == "apps-uninstall" and len(rest) == 1:
            await _fast_apps_uninstall(udid, rest[0])
            return
        if op == "apps-install" and len(rest) == 1:
            await _fast_apps_install(udid, rest[0])
            return
        if op == "clipboard-set":
            text = rest[0] if rest else ""
            await _fast_clipboard_set(udid, text, keep_rsd=True)
            return
        if op.startswith("afc-") and len(rest) >= 1:
            await _fast_afc_op(udid, op[len("afc-") :], rest)
            return
        if op == "pcap-start" and len(rest) >= 1:
            out_file = rest[0]
            proc = rest[1] if len(rest) > 1 and rest[1] else None
            iface = rest[2] if len(rest) > 2 and rest[2] else None
            await _fast_pcap_start(udid, out_file, process=proc, interface=iface)
            return
        if op == "pcap-status":
            await _fast_pcap_status(udid)
            return
        if op == "pcap-stop":
            await _fast_pcap_stop(udid)
            return
    raise RuntimeError(f"unsupported daemon command: {cmd}")


async def _run_daemon_loop() -> None:
    real_stdin = sys.__stdin__ or sys.stdin
    real_stdout = sys.__stdout__ or sys.stdout
    while True:
        line = await asyncio.to_thread(real_stdin.readline)
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        req = json.loads(line)
        req_id = req.get("id")
        cmd = req.get("args", [])
        buf = io.StringIO()
        prev_stdout = sys.stdout
        sys.stdout = buf
        try:
            await _dispatch_daemon_cmd(cmd)
            resp = {"id": req_id, "ok": True, "output": buf.getvalue()}
        except Exception as exc:
            resp = {"id": req_id, "ok": False, "error": str(exc)}
        finally:
            sys.stdout = prev_stdout
        real_stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
        real_stdout.flush()


def _fast_path() -> bool:
    args = sys.argv[1:]
    if args == ["--daemon"]:
        asyncio.run(_run_daemon_loop())
        return True
    if args == ["version"]:
        from importlib.metadata import version

        print(version("pymobiledevice3"))
        return True
    if args == ["usbmux", "list"]:
        asyncio.run(_fast_usbmux_list())
        return True
    if len(args) == 4 and args[:3] == ["crash", "ls", "--udid"]:
        asyncio.run(_fast_crash_ls(args[3]))
        return True
    if len(args) == 6 and args[:3] == ["crash", "pull", "--udid"]:
        asyncio.run(_fast_crash_pull(args[3], args[4], args[5]))
        return True
    if len(args) == 6 and args[:4] == ["developer", "dvt", "screenshot", "--udid"]:
        asyncio.run(_fast_screenshot(args[4], args[5]))
        return True
    if len(args) >= 4 and args[0] == "adb-tool-ios" and args[2] == "--udid":
        op = args[1]
        udid = args[3]
        rest = args[4:]
        if op == "status":
            asyncio.run(_fast_status(udid))
            return True
        if op == "props":
            asyncio.run(_fast_props(udid))
            return True
        if op == "apps-list":
            asyncio.run(_fast_apps_list(udid))
            return True
        if op == "apps-uninstall" and len(rest) == 1:
            asyncio.run(_fast_apps_uninstall(udid, rest[0]))
            return True
        if op == "apps-install" and len(rest) == 1:
            asyncio.run(_fast_apps_install(udid, rest[0]))
            return True
        if op == "clipboard-set":
            text = rest[0] if rest else sys.stdin.read()
            asyncio.run(_fast_clipboard_set(udid, text))
            return True
        if op.startswith("afc-") and len(rest) >= 1:
            asyncio.run(_fast_afc_op(udid, op[len("afc-") :], rest))
            return True
        if op == "pcap-start" and len(rest) >= 1:
            out_file = rest[0]
            proc = rest[1] if len(rest) > 1 and rest[1] else None
            iface = rest[2] if len(rest) > 2 and rest[2] else None
            asyncio.run(_fast_pcap_start(udid, out_file, process=proc, interface=iface))
            return True
        if op == "pcap-status":
            asyncio.run(_fast_pcap_status(udid))
            return True
        if op == "pcap-stop":
            asyncio.run(_fast_pcap_stop(udid))
            return True
    return False


if __name__ == "__main__":
    freeze_support()
    if _fast_path():
        raise SystemExit(0)
    from pymobiledevice3.__main__ import main

    raise SystemExit(main())
