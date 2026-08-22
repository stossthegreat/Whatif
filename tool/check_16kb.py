#!/usr/bin/env python3
"""Verify that a built APK or AAB supports 16 KB memory page sizes.

Google Play requires this of every app targeting API 35+, and from
1 Feb 2027 an app update that fails it cannot be released at all.

Nothing in build.gradle.kts can prove compliance, because the part that
actually breaks is compiled into third-party prebuilt .so files. This script
inspects a real artifact and checks both halves:

  1. ELF LOAD-segment alignment inside every 64-bit .so  (p_align >= 16384)
     Baked in by whoever compiled the library. If this fails, the fix is a
     plugin upgrade, not a Gradle setting.

  2. Zip alignment of those .so entries inside an APK  (stored, offset % 16384)
     Produced by AGP 8.5.1+ when jniLibs.useLegacyPackaging = false.

32-bit ABIs are reported but never fail the run: the Play requirement applies
to 64-bit devices.

Usage:
    tool/check_16kb.py build/app/outputs/flutter-apk/app-release.apk
    tool/check_16kb.py build/app/outputs/bundle/release/app-release.aab

An .aab stores its libraries compressed, so only check 1 is meaningful there.
For check 2, generate APKs first:
    bundletool build-apks --bundle=app-release.aab --output=out.apks --mode=universal
and run this script against the extracted universal.apk.
"""

import struct
import sys
import zipfile

PAGE = 16 * 1024
PT_LOAD = 1
ABIS_64 = ("arm64-v8a", "x86_64")


def load_aligns(blob: bytes):
    """Return (is_64bit, [p_align of every PT_LOAD]) for an ELF image."""
    if blob[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    is64 = blob[4] == 2
    endian = "<" if blob[5] == 1 else ">"
    if not is64:
        return False, []
    e_phoff, = struct.unpack_from(endian + "Q", blob, 0x20)
    e_phentsize, e_phnum = struct.unpack_from(endian + "HH", blob, 0x36)
    aligns = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, = struct.unpack_from(endian + "I", blob, off)
        if p_type != PT_LOAD:
            continue
        p_align, = struct.unpack_from(endian + "Q", blob, off + 48)
        aligns.append(p_align)
    return True, aligns


def data_offset(zf: zipfile.ZipFile, info: zipfile.ZipInfo) -> int:
    """Byte offset of an entry's payload, read from its LOCAL header.

    The central directory's name/extra lengths differ from the local ones, so
    the local header is the only place this can be computed correctly.
    """
    fh = zf.fp
    fh.seek(info.header_offset)
    head = fh.read(30)
    name_len, extra_len = struct.unpack_from("<HH", head, 26)
    return info.header_offset + 30 + name_len + extra_len


def main(path: str) -> int:
    is_aab = path.endswith(".aab")
    prefix = "base/lib/" if is_aab else "lib/"

    with zipfile.ZipFile(path) as zf:
        libs = [i for i in zf.infolist()
                if i.filename.startswith(prefix) and i.filename.endswith(".so")]
        if not libs:
            print(f"no native libraries in {path} — nothing to check, "
                  f"the app is 16 KB compatible by definition")
            return 0

        failures = []
        skipped = 0
        print(f"{path}  ({len(libs)} shared libraries)\n")
        print(f"{'library':<58} {'ELF':<10} {'zip':<10}")
        print("-" * 80)

        for info in sorted(libs, key=lambda i: i.filename):
            abi = info.filename[len(prefix):].split("/")[0]
            short = info.filename[len(prefix):]

            try:
                is64, aligns = load_aligns(zf.read(info))
            except (ValueError, struct.error) as e:
                print(f"{short:<58} UNREADABLE ({e})")
                failures.append((short, f"could not parse: {e}"))
                continue

            if not is64 or abi not in ABIS_64:
                skipped += 1
                continue

            elf_ok = bool(aligns) and all(a >= PAGE for a in aligns)
            elf_cell = "OK" if elf_ok else f"{min(aligns) if aligns else 0} B"

            if is_aab:
                zip_cell = "n/a"
                zip_ok = True
            else:
                stored = info.compress_type == zipfile.ZIP_STORED
                off = data_offset(zf, info)
                zip_ok = stored and off % PAGE == 0
                zip_cell = "OK" if zip_ok else ("compressed" if not stored else "misaligned")

            print(f"{short:<58} {elf_cell:<10} {zip_cell:<10}")
            if not elf_ok:
                failures.append((short,
                                 f"ELF LOAD segments aligned to "
                                 f"{min(aligns) if aligns else 0} bytes, need {PAGE}"))
            if not zip_ok:
                failures.append((short, f"zip entry {zip_cell}"))

    print("-" * 80)
    if skipped:
        print(f"({skipped} 32-bit libraries skipped — the Play requirement is "
              f"about 64-bit devices)")

    if failures:
        print(f"\nFAIL — {len(failures)} problem(s):\n")
        for name, why in failures:
            print(f"  {name}\n      {why}")
        print("\nAn ELF failure is baked into a prebuilt library: upgrade the plugin\n"
              "that ships it (see the livekit_client note in pubspec.yaml).\n"
              "A zip failure is ours: check jniLibs.useLegacyPackaging in\n"
              "android/app/build.gradle.kts and that AGP is 8.5.1 or newer.")
        return 1

    print("\nPASS — every 64-bit library supports 16 KB page sizes.")
    if is_aab:
        print("Note: an .aab keeps libraries compressed, so zip alignment was not\n"
              "checked. Run this against a bundletool-generated universal.apk to\n"
              "verify the half AGP is responsible for.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
