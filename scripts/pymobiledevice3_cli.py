import asyncio
import json
from multiprocessing import freeze_support
import sys


async def _fast_usbmux_list() -> None:
    from pymobiledevice3 import usbmux
    from pymobiledevice3.lockdown import create_using_usbmux

    connected_devices = []
    for device in await usbmux.list_devices():
        lockdown = await create_using_usbmux(
            device.serial,
            autopair=False,
            connection_type=device.connection_type,
        )
        connected_devices.append(lockdown.short_info)
        await lockdown.close()
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


async def _run_daemon_loop() -> None:
    loop = asyncio.get_running_loop()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        req = json.loads(line)
        req_id = req.get("id")
        cmd = req.get("args", [])
        try:
            if cmd == ["usbmux", "list"]:
                from pymobiledevice3 import usbmux
                from pymobiledevice3.lockdown import create_using_usbmux

                connected_devices = []
                for device in await usbmux.list_devices():
                    lockdown = await create_using_usbmux(
                        device.serial,
                        autopair=False,
                        connection_type=device.connection_type,
                    )
                    connected_devices.append(lockdown.short_info)
                    await lockdown.close()
                resp = {"id": req_id, "ok": True, "output": json.dumps(connected_devices, ensure_ascii=False)}
            elif len(cmd) == 4 and cmd[:3] == ["crash", "ls", "--udid"]:
                from pymobiledevice3.lockdown import create_using_usbmux
                from pymobiledevice3.services.crash_reports import CrashReportsManager

                lines = []
                lockdown = await create_using_usbmux(serial=cmd[3])
                try:
                    async with CrashReportsManager(lockdown) as crash_manager:
                        for path in await crash_manager.ls("/", 1):
                            lines.append(path)
                finally:
                    await lockdown.close()
                resp = {"id": req_id, "ok": True, "output": "\n".join(lines) + ("\n" if lines else "")}
            elif len(cmd) == 6 and cmd[:4] == ["crash", "pull", "--udid"]:
                from pymobiledevice3.lockdown import create_using_usbmux
                from pymobiledevice3.services.crash_reports import CrashReportsManager

                lockdown = await create_using_usbmux(serial=cmd[3])
                try:
                    async with CrashReportsManager(lockdown) as crash_manager:
                        await crash_manager.pull(cmd[4], cmd[5], False, None)
                finally:
                    await lockdown.close()
                resp = {"id": req_id, "ok": True, "output": ""}
            else:
                resp = {"id": req_id, "ok": False, "error": f"unsupported daemon command: {cmd}"}
        except Exception as exc:
            resp = {"id": req_id, "ok": False, "error": str(exc)}
        sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
        sys.stdout.flush()
        await asyncio.sleep(0)
        _ = loop


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
    if len(args) == 6 and args[:4] == ["crash", "pull", "--udid"]:
        asyncio.run(_fast_crash_pull(args[3], args[4], args[5]))
        return True
    return False


if __name__ == "__main__":
    freeze_support()
    if _fast_path():
        raise SystemExit(0)
    from pymobiledevice3.__main__ import main

    raise SystemExit(main())
