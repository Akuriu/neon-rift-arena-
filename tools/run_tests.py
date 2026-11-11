#!/usr/bin/env python3
"""Run the project test suites with disposable Godot profiles."""

import argparse
from contextlib import ExitStack
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time


PROJECT = Path(__file__).resolve().parents[1]
ERRORS = ("SCRIPT ERROR:", "SHADER ERROR:", "ERROR:", "FAIL ", "WARNING: Sending ")


def launch(engine, directory, name, args):
    storage = directory / name
    storage.mkdir()
    log = storage / "godot.log"
    command = [engine, "--headless", "--path", str(PROJECT), *args]
    environment = dict(os.environ, NEON_QA_ISOLATED="1", XDG_DATA_HOME=str(storage),
                       XDG_CONFIG_HOME=str(storage), XDG_CACHE_HOME=str(storage),
                       NEON_QA_PROFILE_PATH=str(storage), APPDATA=str(storage), LOCALAPPDATA=str(storage))
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, env=environment)
    return process, log


def read(log):
    return log.read_text(encoding="utf-8", errors="replace")


def check(process, log, name, deadline, require_pass=True):
    try:
        process.wait(timeout=max(0.0, deadline - time.monotonic()))
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        print(f"FAIL {name} timed out")
        return False
    output = read(log)
    print(f"\n--- {name} ---\n{output.rstrip()}", flush=True)
    good = process.returncode == 0 and (not require_pass or "PASS " in output)
    return good and not any(line.startswith(ERRORS) for line in output.splitlines())


def scenario(engine, directory, name, *args, require_pass=True, seconds=180):
    process, log = launch(engine, directory, name, args)
    return check(process, log, name, time.monotonic() + seconds, require_pass)


def coop(engine, directory, players):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    deadline = time.monotonic() + 130
    running = []

    def peer(role):
        name = f"coop-{players}-{role}"
        process, log = launch(engine, directory, name,
                              ["--script", "res://tests/v2_coop.gd", "--", role, str(port), str(players)])
        running.append((process, log, name))
        return process, log

    with ExitStack() as cleanup:
        cleanup.callback(lambda: stop(running))
        host, host_log = peer("host")
        while "HOST READY" not in read(host_log) and host.poll() is None and time.monotonic() < deadline:
            time.sleep(0.1)
        if "HOST READY" not in read(host_log):
            print(read(host_log))
            return False
        rejected = []
        for role in ["version", "password"]:
            process, log = peer(role)
            rejected.append(check(process, log, role, min(deadline, time.monotonic() + 15)))
        peer("rejoin")
        for number in range(players - 2):
            peer(f"client-{number + 2}")
        results = [check(process, log, name, deadline) for process, log, name in running]
        return all(rejected + results)


def stop(running):
    for process, _, _ in running:
        if process.poll() is None:
            process.kill()
            process.wait()


def dedicated(engine, directory):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    host, host_log = launch(engine, directory, "dedicated-host",
                            ["--quit-after", "630", "--", "--server", f"--port={port}",
                             "--map=skyline", "--mode=short", "--difficulty=discovery", "--code=rift-qa"])
    running = [(host, host_log, "dedicated-host")]
    with ExitStack() as cleanup:
        cleanup.callback(lambda: stop(running))
        deadline = time.monotonic() + 25
        while "COOP dedicated" not in read(host_log) and host.poll() is None and time.monotonic() < deadline:
            time.sleep(0.1)
        for number in (1, 2):
            name = f"dedicated-client-{number}"
            process, log = launch(engine, directory, name, ["--script", "res://tests/v2_coop.gd", "--",
                                                           "dedicated", str(port), "2"])
            running.append((process, log, name))
        results = [check(process, log, name, deadline, require_pass=number != 0)
                   for number, (process, log, name) in enumerate(running)]
        output = read(host_log)
        return all(results) and "MATCH started with 2 players" in output and "COOP dedicated ready" in output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--suite", choices=["all", "solo", "coop2", "coop4", "dedicated", "soak"], default="all")
    parser.add_argument("--soak-seconds", type=int, choices=range(10, 1801), default=1200, metavar="10–1800")
    parser.add_argument("--logs", type=Path, help="new directory for logs and disposable saves")
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if engine is None:
        parser.error("Godot introuvable. Utilisez --godot avec le chemin de Godot 4.6.3.")
    with ExitStack() as stack:
        if args.logs:
            directory = args.logs.resolve()
            directory.mkdir(parents=True)
        else:
            directory = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="neon-qa-")))
        if not scenario(engine, directory, "import", "--editor", "--import", require_pass=False):
            return 1
        outcomes = []
        if args.suite in ("all", "solo"):
            for script in ["boot_flow", "map_loading", "ui_navigation"]:
                outcomes.append(scenario(engine, directory, script, "--script", f"res://tests/{script}.gd"))
            for script in ["regression", "profile_recovery", "v2_wave_generation", "v2_systems",
                           "v3_feeling", "v3_modes", "v7_gungame", "v7_parkour", "v7_interactions", "v7_motion", "v3_career", "v3_field", "export_smoke"]:
                outcomes.append(scenario(engine, directory, script, "--fixed-fps", "60",
                                         "--script", f"res://tests/{script}.gd"))
            outcomes.append(scenario(engine, directory, "v3_touch", "--fixed-fps", "60",
                                     "--script", "res://tests/v3_touch.gd", "--", "--touch"))
            outcomes.append(scenario(engine, directory, "v7_touch", "--fixed-fps", "60",
                                     "--script", "res://tests/v7_touch.gd", "--", "--touch"))
            outcomes.append(scenario(engine, directory, "v6_acceptance", "--fixed-fps", "60",
                                     "--script", "res://tests/v6_acceptance.gd", "--", "--touch"))
            for fps in (30, 45, 60):
                outcomes.append(scenario(engine, directory, f"v6_camera_{fps}", "--fixed-fps", str(fps),
                                         "--script", "res://tests/v6_camera.gd"))
            for fps in (30, 45, 60, 90):
                outcomes.append(scenario(engine, directory, f"ui_motion_{fps}", "--fixed-fps", str(fps),
                                         "--script", "res://tests/ui_motion.gd"))
            for mode, arena in [("survival", "cryo"), ("short", "skyline"), ("trial", "reactor"), ("boss_rush", "reactor")]:
                outcomes.append(scenario(engine, directory, mode, "--fixed-fps", "120",
                                         "--script", "res://tests/survival.gd", "--", mode, arena, "discovery"))
        for count in (2, 4):
            if args.suite in ("all", f"coop{count}"):
                outcomes.append(coop(engine, directory, count))
        if args.suite in ("all", "dedicated"):
            outcomes.append(dedicated(engine, directory))
        if args.suite == "soak":
            outcomes.append(scenario(engine, directory, "v6_soak", "--script", "res://tests/v6_soak.gd",
                                     "--", "--touch", f"--seconds={args.soak_seconds}",
                                     seconds=args.soak_seconds + 60))
        return 0 if all(outcomes) else 1


if __name__ == "__main__":
    raise SystemExit(main())
