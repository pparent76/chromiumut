#!/bin/bash
set -e  # Exit immediately on error



# ========================
# PROJECT CONFIGURATION
# ========================
PROJECT_NAME="chromiumut"
SNAP_FILE="${BUILD_DIR}/chromium-desktop.snap"
EXTRACT_DIR="${BUILD_DIR}/squashfs-root"
INSTALL_DIR="${BUILD_DIR}/install"
EXPECTED_HASH=""


# ========================
# STEP 1: PREPARATION
# ========================
echo "[1/9] Cleaning up..."
rm -rf "$EXTRACT_DIR" "$INSTALL_DIR"
mkdir -p "$EXTRACT_DIR" "$INSTALL_DIR"


# ========================
# STEP 2: DOWNLOAD THE LATEST Chrome  SNAP USING SNAP
# ========================
echo "[2/9] Downloading latest Chrome via snap..."
mkdir -p "$EXTRACT_DIR"


# Télécharge le snap sans l’installer globalement
cd ${BUILD_DIR}
DOWNLOAD_URL=$(curl -s https://api.snapcraft.io/v2/snaps/info/chromium -H "Snap-Device-Series: 16" -H "Snap-Architecture: arm64" | jq -r '.["channel-map"][] 
            | select(.channel.architecture=="arm64" and .channel.name=="stable") 
            | .download.url'
            )
curl -L -o "$SNAP_FILE" "$DOWNLOAD_URL"
# ========================
# STEP 3: EXTRACTION
# ========================
echo "[3/9] Extracting .snap package..."
rm -r $EXTRACT_DIR
echo "Extracting $SNAP_FILE to $EXTRACT_DIR"
unsquashfs "$SNAP_FILE"
rm $EXTRACT_DIR/usr/bin/xdg-email

# ===================================
# STEP 4: BUILD THE FAKE xdg-open
# ===================================
echo "[4/10] Building fake xdg-open ..."
cp -r ${ROOT}/utils/xdg-open/ ${BUILD_DIR}/
cd ${BUILD_DIR}/xdg-open/
mkdir -p build
cd build
cmake ..
make

# ===================================
# STEP 4: Install DEPENDENCIES
# ===================================
echo "[5/9] Install dependencies..."

cd ${BUILD_DIR}
DEPENDENCIES="libhybris-utils xdotool libmaliit-glib2 libxdo3 x11-utils"

for dep in $DEPENDENCIES ; do
    apt download $dep:arm64
    mv ${dep}_*.deb ${dep}.deb
    rm -rvf "${dep}.deb_extract_chsdjksd" || true
    mkdir "${dep}.deb_extract_chsdjksd"
    dpkg-deb -x "${dep}.deb" "${dep}.deb_extract_chsdjksd"
done

# =================================================
# STEP 6: Downloading maliit-inputcontext-gtk3
# =================================================

echo "[6/9] Building maliit-inputcontext-gtk3 and download dependencies..."


PKGNAME="maliit-inputcontext-gtk"
VERSION="0.99.1+git20151116.72d7576"
ORIG_URL="https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/maliit-inputcontext-gtk/0.99.1+git20151116.72d7576-3build3/maliit-inputcontext-gtk_0.99.1+git20151116.72d7576.orig.tar.xz"
DEBIAN_URL="https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/maliit-inputcontext-gtk/0.99.1+git20151116.72d7576-3build3/maliit-inputcontext-gtk_0.99.1+git20151116.72d7576-3build3.debian.tar.xz"



WORKDIR_MALIIT="${PKGNAME}-${VERSION}"
rm -rvf $WORKDIR_MALIIT/ || true
mkdir -p "$WORKDIR_MALIIT"
cd "$WORKDIR_MALIIT"

echo "📦 Download sources..."
wget -q "$ORIG_URL" -O "${PKGNAME}_${VERSION}.orig.tar.xz"
wget -q "$DEBIAN_URL" -O "${PKGNAME}_${VERSION}.debian.tar.xz"

echo "📂 Extract original code..."
tar -xf "${PKGNAME}_${VERSION}.orig.tar.xz"
SRC_DIR_MALIIT=$(tar -tf "${PKGNAME}_${VERSION}.orig.tar.xz" | head -1 | cut -d/ -f1)

echo "📂 Extract debian files..."
tar -xf "${PKGNAME}_${VERSION}.debian.tar.xz" -C "$SRC_DIR_MALIIT"

echo "Apply patch..."
cd ${BUILD_DIR}/$SRC_DIR_MALIIT/maliit-inputcontext-gtk-$VERSION/
patch ${BUILD_DIR}/$SRC_DIR_MALIIT/maliit-inputcontext-gtk-$VERSION/gtk-input-context/client-gtk/client-imcontext-gtk.c  ${ROOT}/patches/maliit-inputcontext-gtk/client-imcontext-gtk.c.patch
echo "${ROOT}/patches/maliit-inputcontext-gtk/client-imcontext-gtk.c.patch"

echo "Compile..."
EDITOR=true dpkg-source --commit . fix-keyboard
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -a arm64

echo "[7/9] Copying files..." 


echo "Copying dependencies..."
cd ${BUILD_DIR}
# Copie des fichiers du dossier /lib/ de chaque paquet
rm -rvf $INSTALL_DIR/lib
mkdir -p "$INSTALL_DIR/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/"
for DIR in *_extract_chsdjksd; do
    if [ -d "$DIR/usr/lib/aarch64-linux-gnu/" ]; then
        cp -r "$DIR/usr/lib/aarch64-linux-gnu/"* "$INSTALL_DIR/lib/aarch64-linux-gnu/"
    fi
done

echo "done"
# Copy binaries in bin/
mkdir -p "$INSTALL_DIR/bin"
cp *_extract_chsdjksd/usr/bin/xdotool "$INSTALL_DIR/bin/"
cp *_extract_chsdjksd/usr/bin/getprop "$INSTALL_DIR/bin/"
cp *_extract_chsdjksd/usr/bin/xprop "$INSTALL_DIR/bin/"
cp *_extract_chsdjksd/usr/bin/xev "$INSTALL_DIR/bin/"

echo "Copying maliit-input-context..."
cp ${ROOT}/patches/maliit-inputcontext-gtk/immodules.cache $INSTALL_DIR/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/
cp ${BUILD_DIR}/$WORKDIR_MALIIT/maliit-inputcontext-gtk-$VERSION/builddir/gtk3/gtk-3.0/im-maliit.so $INSTALL_DIR/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/




echo "[8/9] Copying Chrome to $INSTALL_DIR/usr..."
mkdir -p "$INSTALL_DIR/usr/"
cp -r "$EXTRACT_DIR/usr/" "$INSTALL_DIR/" || true


mkdir -p "$INSTALL_DIR/utils/"
cp ${ROOT}/utils/sleep.sh "$INSTALL_DIR/utils/"
cp ${ROOT}/utils/get-scale.sh "$INSTALL_DIR/utils/"
cp ${BUILD_DIR}/xdg-open/build/xdg-open $INSTALL_DIR/bin/

# Copy project files
cp ${ROOT}/launcher.sh "$INSTALL_DIR/"
cp ${ROOT}/chromiumut.desktop "$INSTALL_DIR/"
cp ${ROOT}/icon.png "$INSTALL_DIR/"
cp ${ROOT}/icon-splash.png "$INSTALL_DIR/"
cp ${ROOT}/manifest.json "$INSTALL_DIR/"
cp ${ROOT}/chromiumut.apparmor "$INSTALL_DIR/"

chmod +x $INSTALL_DIR/utils/sleep.sh
chmod +x $INSTALL_DIR/utils/get-scale.sh
chmod +x $INSTALL_DIR/launcher.sh
chmod +x $INSTALL_DIR/usr/lib/chromium-browser/chrome
chmod +x $INSTALL_DIR/usr/lib/chromium-browser/chrome_crashpad_handler

# ========================
# STEP 6: BUILD THE CLICK PACKAGE
# ========================
echo "[9/9] Building click package..."
# click build "$INSTALL_DIR"

echo "✅ Preparation done, building the .click package."
 
