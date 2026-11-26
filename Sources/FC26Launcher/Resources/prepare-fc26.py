"""RecompLauncher Easy Setup for the pinned FC 26 nxnative profile."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile

TITLE = "01004FF021942000"
VERSION = 1179648
MAIN_BUILD = "a6ee52983a8349342d0ec70f609afa69"
PACKER_VERSION = 1
APP = "EA-Sports-FC-26.app"


def progress(fraction, message):
    print(f"progress {fraction:.3f} {message}", flush=True)


def file_input(value, label, extensions=()):
    path = value.expanduser()
    if (extensions and path.suffix.lower() not in extensions) or not path.is_file():
        raise ValueError(f"Choose a readable {label}.")
    with path.open("rb"):
        pass
    return path.resolve()


def ready(app):
    return all((app / name).is_file() for name in (
        "Contents/MacOS/nxnative", "Contents/MacOS/dmhost",
        "Contents/Resources/romfs.img", "Contents/Resources/dm/launcher.json",
    ))


def build(script, repo, inputs, keys, work, output):
    args = [
        sys.executable, "-u", str(script), str(inputs), "--keys", str(keys),
        "--title-id", TITLE, "--package", f"v{VERSION}", "--platform", "mac-app",
        "--keep-extracted", "--work-dir", str(work), "--out", str(output),
        "--progress", "json",
    ]
    stage_count, reported = 1, 0.08
    with subprocess.Popen(args, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, errors="replace") as process:
        for line in process.stdout:
            try:
                event = json.loads(line)
            except ValueError:
                print(line.rstrip(), flush=True)
                continue
            kind = event.get("ev")
            if kind == "stage":
                stage_count = max(event["n"], 1)
            if kind in ("stage", "step", "progress") and event.get("k", 0) > 0:
                fraction = (event["k"] - 1 + (event.get("frac") or 0)) / stage_count
                reported = max(reported, min(0.94, 0.08 + 0.86 * fraction))
                progress(reported, event.get("step") or event["name"])
            if kind == "say":
                print(event["msg"], flush=True)
        if process.wait() != 0:
            raise ValueError("nxnative could not build FC 26. Check the error above and the build logs.")


def verify_packages(repo, script, packages, keys):
    # Ask nxnative's own package reader for the decrypted CNMT metadata, never trust filenames.
    sys.path.insert(0, str(script.parent))
    sys.dont_write_bytecode = True
    import build_ipa_from_nsp as builder

    environment = dict(os.environ)
    environment["PATH"] = os.pathsep.join(builder.TOOL_PATHS + [environment["PATH"]])
    builder.configure_dotnet(environment)
    requirements = (("Application", int(TITLE, 16), 0), ("Patch", int(TITLE, 16) | 0x800, VERSION))
    with builder.package_title_reader(repo, keys, environment) as reader:
        for package, expected, label in zip(packages, requirements, ("base game", "1.86.1233 update")):
            if expected not in (reader.contents(package) or ()):
                raise ValueError(f"The selected {label} does not match FC 26, or could not be read with your prod.keys.")
    return builder.build_id


def set_up(args):
    data = Path(os.environ["RECOMPLAUNCHER_DATA"])
    if not data.is_absolute():
        raise ValueError("RecompLauncher must supply an absolute data path.")
    base = file_input(args.game, "base game (.nsp or .xci)", (".nsp", ".xci"))
    update = file_input(args.update, "1.86.1233 update (.nsp)", (".nsp",))
    keys = file_input(args.keys, "prod.keys file")
    if base.samefile(update):
        raise ValueError("Choose the base game and the update as two separate files.")

    repo = Path.home() / "nxnative"
    script = repo / "scripts/build_ipa_from_nsp.py"
    profile = repo / "dm/games" / TITLE / "game.tsv"
    if not script.is_file() or not profile.is_file() or MAIN_BUILD not in profile.read_text():
        raise ValueError("Set up nxnative at ~/nxnative with the FC 26 patch as described in the FC26Launcher README.")

    # nxnative can reuse extracted content for the same version. Isolate it whenever an input changes.
    sources = []
    for path in (base, update, keys, script, profile):
        info = path.stat()
        sources.append((str(path), info.st_size, info.st_mtime_ns, info.st_ctime_ns))
    fingerprint = hashlib.sha256(json.dumps([PACKER_VERSION, sources]).encode()).hexdigest()

    cache = data / "cache"
    cache.mkdir(parents=True, exist_ok=True)
    with (cache / "prepare.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("FC 26 setup is already running.") from None

        app = data / APP
        receipt = data / "prepared"
        previous = cache / "previous.app"
        if not app.exists() and previous.exists():
            previous.rename(app)
        if ready(app) and receipt.is_file() and receipt.read_text() == fingerprint:
            progress(1, "Already built")
            return

        progress(0.02, "Checking your base game and update")
        build_id = verify_packages(repo, script, (base, update), keys)
        work = cache / "build"
        work_stamp = cache / "build-inputs"
        if not work_stamp.is_file() or work_stamp.read_text() != fingerprint:
            if work.exists():
                shutil.rmtree(work)
            work_stamp.write_text(fingerprint)

        with tempfile.TemporaryDirectory(prefix="fc26-inputs-") as temporary:
            inputs = Path(temporary)
            (inputs / f"FC 26 [{TITLE}][v0]{args.game.suffix.lower()}").symlink_to(base)
            (inputs / f"FC 26 [{int(TITLE, 16) | 0x800:016X}][v{VERSION}].nsp").symlink_to(update)
            output = cache / APP
            if output.exists():
                shutil.rmtree(output)
            progress(0.08, "Building FC 26 with nxnative")
            build(script, repo, inputs, keys, work, output)

        if build_id(work / "extract" / f"v{VERSION}" / "ExeFS/main") != MAIN_BUILD or not ready(output):
            raise ValueError("The build does not match the supported FC 26 update (1.86.1233).")

        pending = cache / "prepared.pending"
        pending.write_text(fingerprint)
        if previous.exists():
            shutil.rmtree(previous)
        # Keep the previous playable build until the new one has passed all checks.
        receipt.unlink(missing_ok=True)
        if app.exists():
            app.rename(previous)
        try:
            output.rename(app)
        except OSError:
            if previous.exists():
                previous.rename(app)
            raise
        pending.replace(receipt)
        if previous.exists():
            shutil.rmtree(previous)
        progress(1, "FC 26 is ready to play")


def main():
    parser = argparse.ArgumentParser(description="Prepare FC 26 from your own Switch dumps.")
    for option in ("game", "update", "keys"):
        parser.add_argument(f"--{option}", required=True, type=Path)
    args = parser.parse_args()
    if sys.version_info < (3, 12) or platform.machine() != "arm64":
        parser.error("FC 26 setup needs arm64 Python 3.12 or later. See the FC26Launcher README.")
    if "RECOMPLAUNCHER_DATA" not in os.environ:
        parser.error("The RecompLauncher data path is missing. Start Easy Setup in RecompLauncher.")
    try:
        set_up(args)
    except Exception as error:
        print(f"FC 26 setup failed: {error}", file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
