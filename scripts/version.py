#!/usr/bin/env python3
"""
Version injection script for PlatformIO builds.
Automatically adds git hash and build timestamp to firmware.
"""

Import("env")
import subprocess
from datetime import datetime
import sys

def get_git_hash():
    """Get current git commit hash."""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--short', 'HEAD'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"

def get_git_branch():
    """Get current git branch name."""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"

def get_build_timestamp():
    """Get current build timestamp."""
    return datetime.now().strftime("%Y%m%d-%H%M%S")

def get_version_from_platformio():
    """Extract version from platformio.ini build flags."""
    for flag in env.get("BUILD_FLAGS", []):
        if flag.startswith("-DVERSION="):
            return flag.replace("-DVERSION=", "").strip('"')
    return "dev"

# Get version information
git_hash = get_git_hash()
git_branch = get_git_branch()
build_time = get_build_timestamp()
version = get_version_from_platformio()

# Print version information
print("=" * 60)
print("Building 4-Servo Ornithopter Firmware")
print("=" * 60)
print(f"Version:    {version}")
print(f"Git Hash:   {git_hash}")
print(f"Branch:     {git_branch}")
print(f"Build Time: {build_time}")
print(f"Board:      {env.BoardConfig().get('name')}")
print(f"Platform:   {env.get('PIOPLATFORM')}")
print("=" * 60)

# Add version information to build flags
env.Append(
    CPPDEFINES=[
        ("GIT_HASH", f'\\"{git_hash}\\"'),
        ("GIT_BRANCH", f'\\"{git_branch}\\"'),
        ("BUILD_TIME", f'\\"{build_time}\\"'),
        ("BUILD_VERSION", f'\\"{version}\\"'),
    ]
)

# Add to build environment for use in post-build scripts
env["VERSION_INFO"] = {
    "version": version,
    "git_hash": git_hash,
    "git_branch": git_branch,
    "build_time": build_time,
}
