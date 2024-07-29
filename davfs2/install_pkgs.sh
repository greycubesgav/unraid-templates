#!/usr/bin/env bash

plgname='davfs2'
author='greycubesgav'
gitURL="https://github.com/${author}/unraid-templates/raw/main/${plgname}/"
pluginURL="${gitURL}/${plgname}.plg"
pluginDIR="/boot/config/plugins/${plgname}"
#emhttp="/usr/local/emhttp/plugins/${plgname}"

download_md5() {
  # Download a package and check the md5sum
  pkg="$1"
  pkgURL="${gitURL}packages/${pkg}"
  pkgDST="${pluginDIR}/${pkg}"

  # Download the file
  if ! curl -L -s -f -o "${pkgDST}" "${pkgURL}" > /dev/null; then
    echo "Failed to download pkg to ${pkgDST} from: ${pkgURL}"
    return 1
  fi

  #cp "/mnt/user/gav/Documents/Development/github/greycubesgav.unraid-templates/davfs2/packages/${pkg}" "${pkgDST}"

  # Download the MD5 checksum file
  if ! curl -L -s -f -o "${pkgDST}.md5" "${pkgURL}.md5" > /dev/null; then
    echo "Failed to download pkg MD5 to ${pkgDST}.md5 checksum file: ${pkgURL}.md5"
    rm -f "${pkgDST}"
    return 1
  fi

  #cp "/mnt/user/gav/Documents/Development/github/greycubesgav.unraid-templates/davfs2/packages/${pkg}.md5" "${pkgDST}.md5"

  # Check the MD5 checksum
  echo "${pluginDIR} : md5sum -c '${pkgDST}.md5'"
  if ! cd "${pluginDIR}" && md5sum -c "${pkg}.md5" > /dev/null; then
    echo "MD5 checksum failed for file: ${pkgDST}"
    rm -f "${pkgDST}" "${pkgDST}.md5"
    return 1
  fi

  echo "File downloaded successfully: ${pkgURL} to ${pkgDST}"
  return 0
}

install_pkg() {
  pkg="$1"
  if ! upgradepkg --install-new --reinstall "${pluginDIR}/${pkg}"; then
    echo "Failed to install package: ${pluginDIR}/${pkg}" >&2
    return 1
  fi
  echo "Package installed: ${pluginDIR}/${pkg}"
  return 0
}

dl_install() {
  pkg="$1"
  echo "Downloading package: ${pkg}"
  if ! download_md5 "$pkg"; then
    echo "Issue downloading or MD5 checksum for: ${pkg}" >&2
    return 1
  fi
  if ! install_pkg "$pkg"; then
    echo "Issue installing package: ${pkg}" >&2
    return 1
  fi
}

# Install versions based on openSSL version
if [ -f '/lib64/libssl.so.1.1' ]; then
  # We assume we are running on Unraid 6.X
  src_pkg="davfs2-1.6.1-x86_64-1-GG.txz"
  dep1_pkg="libproxy-0.4.17-x86_64-5.txz"
  dep2_pkg="neon-0.32.2-x86_64-1.txz"
elif [ -f '/lib64/libssl.so.3' ]; then
  # We assume we are running on Unraid 7.X
  src_pkg='davfs2-1.6.1-x86_64-1_GG_UR7.tgz'
  dep1_pkg='libproxy-0.5.8-x86_64-1.txz'
  dep2_pkg='neon-0.33.0-x86_64-2.txz'
  dep3_pkg='duktape-2.7.0-x86_64-1.txz'
else
  echo "Failed to detect a known version of the openssl library" >&2
  echo "Local version appears to be : $(ls -l /lib64/libssl\.*)" >&2
  exit 1
fi

if [ ! -d "${pluginDIR}" ]; then
  if ! mkdir -p "${pluginDIR}"; then
    echo "Failed to create plugin directory: ${pluginDIR}" >&2
    exit 2
  fi
fi

if [ -n "${dep3_pkg}" ]; then
  if ! dl_install "${dep3_pkg}"; then
    echo "Issue with ${dep3_pkg} install exiting..." >&2
    exit 10
  fi
fi

if ! dl_install "${dep2_pkg}"; then
  echo "Issue with ${dep2_pkg} install exiting..." >&2
  exit 10
fi

if ! dl_install "${dep1_pkg}"; then
  echo "Issue with ${dep1_pkg} install exiting..." >&2
  removepkg "${pluginURL}/${dep2_pkg}"
  exit 11
fi

if ! dl_install "${src_pkg}"; then
  echo "Issue with ${src_pkg} install exiting..." >&2
  removepkg "${pluginURL}/${dep1_pkg}"
  removepkg "${pluginURL}/${dep2_pkg}"
  exit 12
fi

echo "Successfully installed $plgname."
exit 0
