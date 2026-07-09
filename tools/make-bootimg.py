#!/usr/bin/env python3
"""
Pico Neo 2 — Boot Image Builder

Creates a boot image with the correct format for ABL:
- Android boot image v0 header (ANDROID! magic)
- Kernel compressed with "fake gzip" format (gzip header + deflate + footer + raw DTB)
- Original header fields preserved from boot_backup.img
- Original ramdisk preserved

Usage:
    python3 make-bootimg.py <kernel_image> <dtb> [--cmdline CMDLINE] [--output OUT]
    python3 make-bootimg.py --original   # Just copy original with modified cmdline
"""

import struct
import zlib
import hashlib
import argparse
import os
import sys

PAGE_SIZE = 4096
BOOT_IMAGE_SIZE = 67108864  # 64 MB

def read_file(path):
    with open(path, 'rb') as f:
        return f.read()

def make_fake_gzip(kernel_raw, dtb_raw):
    """Create fake-gzip package: gzip_header + deflate(kernel) + gzip_footer + raw_dtb"""
    gzip_header = bytes([0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x03])
    
    compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    deflated = compressor.compress(kernel_raw)
    deflated += compressor.flush()
    
    crc = zlib.crc32(kernel_raw) & 0xffffffff
    isize = len(kernel_raw) & 0xffffffff
    gzip_footer = struct.pack('<II', crc, isize)
    
    return gzip_header + deflated + gzip_footer + dtb_raw

def build_boot_image(kernel_pkg, orig_boot_img, cmdline=None):
    """Build a boot image using original header and ramdisk"""
    orig = bytearray(orig_boot_img)
    out = bytearray(BOOT_IMAGE_SIZE)
    
    # Copy original header (first page)
    out[:PAGE_SIZE] = orig[:PAGE_SIZE]
    
    # Update kernel size
    struct.pack_into('<I', out, 8, len(kernel_pkg))
    
    # Override cmdline if provided
    if cmdline:
        cmdline_bytes = cmdline.encode('ascii') + b'\x00' * (512 - len(cmdline))
        out[64:64+512] = cmdline_bytes[:512]
    
    # Write kernel package
    out[PAGE_SIZE:PAGE_SIZE + len(kernel_pkg)] = kernel_pkg
    
    # Copy original ramdisk
    orig_ramdisk_size = struct.unpack('<I', orig[16:20])[0]
    orig_kernel_size = struct.unpack('<I', orig[8:12])[0]
    kernel_pages = (orig_kernel_size + PAGE_SIZE - 1) // PAGE_SIZE
    ramdisk_offset = (1 + kernel_pages) * PAGE_SIZE
    orig_ramdisk = orig[ramdisk_offset:ramdisk_offset + orig_ramdisk_size]
    
    our_kernel_pages = (len(kernel_pkg) + PAGE_SIZE - 1) // PAGE_SIZE
    new_ramdisk_offset = (1 + our_kernel_pages) * PAGE_SIZE
    out[new_ramdisk_offset:new_ramdisk_offset + len(orig_ramdisk)] = orig_ramdisk
    
    # Recompute boot_id (SHA1 at offset 0x240)
    sha = hashlib.sha1()
    sha.update(out[8:12])
    sha.update(out[16:20])
    sha.update(out[24:28])
    sha.update(kernel_pkg)
    sha.update(orig_ramdisk)
    out[0x240:0x254] = sha.digest()
    
    return bytes(out)

def main():
    parser = argparse.ArgumentParser(description='Pico Neo 2 Boot Image Builder')
    parser.add_argument('kernel', nargs='?', help='Kernel Image file')
    parser.add_argument('dtb', nargs='?', help='DTB file')
    parser.add_argument('--cmdline', default=None, help='Boot cmdline')
    parser.add_argument('--output', '-o', default=None, help='Output boot image path')
    parser.add_argument('--original', action='store_true', help='Use original kernel, only modify cmdline')
    parser.add_argument('--backup', default=None, help='Path to boot_backup.img')
    args = parser.parse_args()
    
    # Find backup image
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    backup_path = args.backup or os.path.join(project_dir, 'backup-images', 'boot_backup.img')
    
    if not os.path.exists(backup_path):
        print(f"ERROR: boot_backup.img not found at {backup_path}", file=sys.stderr)
        sys.exit(1)
    
    orig_boot = read_file(backup_path)
    
    if args.original:
        # Just copy original with modified cmdline
        out = bytearray(orig_boot)
        if args.cmdline:
            cmdline_bytes = args.cmdline.encode('ascii') + b'\x00' * (512 - len(args.cmdline))
            out[64:64+512] = cmdline_bytes[:512]
            # Recompute boot_id
            kernel_size = struct.unpack('<I', out[8:12])[0]
            ramdisk_size = struct.unpack('<I', out[16:20])[0]
            kernel_pkg = out[PAGE_SIZE:PAGE_SIZE + kernel_size]
            kernel_pages = (kernel_size + PAGE_SIZE - 1) // PAGE_SIZE
            ramdisk_offset = (1 + kernel_pages) * PAGE_SIZE
            ramdisk = out[ramdisk_offset:ramdisk_offset + ramdisk_size]
            sha = hashlib.sha1()
            sha.update(out[8:12])
            sha.update(out[16:20])
            sha.update(out[24:28])
            sha.update(kernel_pkg)
            sha.update(ramdisk)
            out[0x240:0x254] = sha.digest()
        
        output_path = args.output or os.path.join(project_dir, 'output', 'boot-custom.img')
        with open(output_path, 'wb') as f:
            f.write(out)
        print(f"Created {output_path} (original kernel, modified cmdline)")
        return
    
    if not args.kernel or not args.dtb:
        parser.error("kernel and dtb are required unless --original is used")
    
    kernel_raw = read_file(args.kernel)
    dtb_raw = read_file(args.dtb)
    
    print(f"Kernel: {len(kernel_raw)} bytes ({len(kernel_raw)/1024/1024:.1f} MB)")
    print(f"DTB: {len(dtb_raw)} bytes")
    
    # Check kernel header
    first_word = struct.unpack('<I', kernel_raw[:4])[0]
    magic = kernel_raw[0x38:0x3c]
    
    if magic == b'ARMd':
        print(f"ARM64 kernel magic OK")
    else:
        print(f"WARNING: ARMd magic not found at 0x38 (got {magic})")
    
    if first_word == 0x5a4d:
        print("WARNING: Kernel starts with MZ (EFI stub). ABL will reject this.")
    
    # Check size against ABL buffer limit
    if len(kernel_raw) > 37 * 1024 * 1024:
        print(f"WARNING: Kernel is {len(kernel_raw)/1024/1024:.1f} MB — may exceed ABL buffer limit (~37 MB)")
    
    # Create fake-gzip package
    kernel_pkg = make_fake_gzip(kernel_raw, dtb_raw)
    print(f"Kernel package: {len(kernel_pkg)} bytes ({len(kernel_pkg)/1024/1024:.1f} MB)")
    
    # Build boot image
    boot_img = build_boot_image(kernel_pkg, orig_boot, args.cmdline)
    
    output_path = args.output or os.path.join(project_dir, 'output', 'boot-custom.img')
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(boot_img)
    print(f"Created {output_path}")

if __name__ == '__main__':
    main()
