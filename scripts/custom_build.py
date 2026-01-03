#!/usr/bin/env python3
"""
Custom post-build script for PlatformIO.
Copies firmware to releases folder and generates build report.
"""

Import("env")
import shutil
from pathlib import Path

def after_build(source, target, env):
    """Post-build callback to organize firmware artifacts."""
    
    # Get version information
    version_info = env.get("VERSION_INFO", {})
    version = version_info.get("version", "dev")
    git_hash = version_info.get("git_hash", "unknown")
    build_time = version_info.get("build_time", "unknown")
    
    # Get build environment name
    env_name = env["PIOENV"]
    
    # Get board MCU
    board_mcu = env.BoardConfig().get("build.mcu", "unknown")
    
    # Create releases directory
    release_dir = Path("releases")
    release_dir.mkdir(exist_ok=True)
    
    # Get firmware files
    firmware_hex = str(target[0])
    firmware_dir = Path(firmware_hex).parent
    
    # Generate release filename
    release_name = f"ornithopter_v{version}_{env_name}_{git_hash}"
    
    # Copy firmware files
    files_to_copy = [
        ("firmware.hex", f"{release_name}.hex"),
        ("firmware.elf", f"{release_name}.elf"),
    ]
    
    for src_name, dst_name in files_to_copy:
        src_path = firmware_dir / src_name
        if src_path.exists():
            dst_path = release_dir / dst_name
            shutil.copy2(src_path, dst_path)
            print(f"✓ Copied {src_name} → {dst_path}")
    
    # Generate build report
    report_path = release_dir / f"{release_name}_build_report.txt"
    with open(report_path, 'w') as f:
        f.write("=" * 60 + "\n")
        f.write("4-Servo Ornithopter Firmware Build Report\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"Version:      {version}\n")
        f.write(f"Git Hash:     {git_hash}\n")
        f.write(f"Build Time:   {build_time}\n")
        f.write(f"Environment:  {env_name}\n")
        f.write(f"Board:        {env.BoardConfig().get('name')}\n")
        f.write(f"MCU:          {board_mcu}\n")
        f.write(f"Platform:     {env.get('PIOPLATFORM')}\n")
        f.write(f"Framework:    {env.get('PIOFRAMEWORK')[0] if env.get('PIOFRAMEWORK') else 'unknown'}\n")
        f.write("\n" + "=" * 60 + "\n")
        f.write("Build Flags:\n")
        f.write("=" * 60 + "\n")
        for flag in env.get("BUILD_FLAGS", []):
            f.write(f"  {flag}\n")
        f.write("\n" + "=" * 60 + "\n")
        f.write("Library Dependencies:\n")
        f.write("=" * 60 + "\n")
        for lib in env.get("LIB_DEPS", []):
            f.write(f"  {lib}\n")
        f.write("\n")
    
    print(f"✓ Generated build report → {report_path}")
    
    # Get firmware size
    try:
        import subprocess
        size_output = subprocess.check_output(
            ["avr-size", "-C", "--mcu=" + board_mcu, str(firmware_hex)],
            stderr=subprocess.STDOUT,
            universal_newlines=True
        )
        print("\nFirmware Size:")
        print(size_output)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    print(f"\n✓ Build artifacts saved to: {release_dir}/")
    print(f"  Base name: {release_name}\n")

# Register post-build callback
env.AddPostAction("$BUILD_DIR/${PROGNAME}.hex", after_build)
