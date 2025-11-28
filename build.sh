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

# ======================================
# STEP 0: Install maliit with crackle
# ======================================
echo "[1/8] Cleaning up..."

# ${ROOT}/crackle/crackle update
# ${ROOT}/crackle/crackle click maliit-inputcontext-gtk3


# ========================
# STEP 1: PREPARATION
# ========================
echo "[2/8] Cleaning up..."
rm -rf "$EXTRACT_DIR" "$INSTALL_DIR"
mkdir -p "$EXTRACT_DIR" "$INSTALL_DIR"
cp -r ${BUILD_DIR}/usr/lib "$INSTALL_DIR"
rm -rf $INSTALL_DIR/lib/x86_64-linux-gnu
# cp -r ${ROOT}/immodules.cache "$INSTALL_DIR/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/immodules.cache"

# ========================
# STEP 2: DOWNLOAD THE LATEST Chrome  SNAP USING SNAP
# ========================
echo "[3/8] Downloading latest Chrome via snap..."
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
echo "[4/8] Extracting .snap package..."
rm -r $EXTRACT_DIR
echo "Extracting $SNAP_FILE to $EXTRACT_DIR"
unsquashfs "$SNAP_FILE"

# ========================
# STEP 4: INSTALL TO TEMP DIRECTORY
# ========================
# ===================================
# STEP 5: BUILD THE FAKE xdg-open
# ===================================
echo "[5/8] Building fake xdg-open ..."
cp -r ${ROOT}/utils/xdg-open/ ${BUILD_DIR}/
cd ${BUILD_DIR}/xdg-open/
mkdir -p build
cd build
cmake ..
make
mkdir -p $INSTALL_DIR/bin/



# =================================================
# STEP 6: Downloading maliit-inputcontext-gtk3
# =================================================
echo "[6/8] Building maliit-inputcontext-gtk3 and download dependencies..."

cd ${BUILD_DIR}
apt download libhybris-utils:arm64
mv libhybris-utils_*.deb libhybris-utils.deb
# URLs des paquets .deb
URL1="http://launchpadlibrarian.net/599174154/libxdo3_3.20160805.1-5_arm64.deb"
URL2="http://launchpadlibrarian.net/723291297/libmaliit-glib2_2.3.0-4build5_arm64.deb"
XDOTOOL_URL="http://launchpadlibrarian.net/599174155/xdotool_3.20160805.1-5_arm64.deb"

# Téléchargement des fichiers .deb
wget -q "$URL1" -O "${BUILD_DIR}/pkg1.deb"
wget -q "$URL2" -O "${BUILD_DIR}/pkg2.deb"
wget -q "$XDOTOOL_URL" -O "${BUILD_DIR}/xdotool.deb"

# Extraction des paquets
cd "${BUILD_DIR}"
for PKG in pkg1.deb pkg2.deb xdotool.deb libhybris-utils.deb; do
    rm -rvf "${PKG%.deb}_extract_chsdjksd" || true
    mkdir "${PKG%.deb}_extract_chsdjksd"
    dpkg-deb -x "$PKG" "${PKG%.deb}_extract_chsdjksd"
done

# Copie des fichiers du dossier /lib/ de chaque paquet
rm -rvf $INSTALL_DIR/lib
mkdir -p "$INSTALL_DIR/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/"
for DIR in *_extract_chsdjksd; do
    if [ -d "$DIR/usr/lib/aarch64-linux-gnu/" ]; then
        cp -r "$DIR/usr/lib/aarch64-linux-gnu/"* "$INSTALL_DIR/lib/aarch64-linux-gnu/"
    fi
done

cp ${ROOT}/patches/maliit-inputcontext-gtk/immodules.cache $INSTALL_DIR/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/
# Copie des binaires xdotool dans bin/
mkdir -p "$INSTALL_DIR/bin"
cp *_extract_chsdjksd/usr/bin/xdotool "$INSTALL_DIR/bin/"
cp *_extract_chsdjksd/usr/bin/getprop "$INSTALL_DIR/bin/"


PKGNAME="maliit-inputcontext-gtk"
VERSION="0.99.1+git20151116.72d7576"
ORIG_URL="https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/maliit-inputcontext-gtk/0.99.1+git20151116.72d7576-3build3/maliit-inputcontext-gtk_0.99.1+git20151116.72d7576.orig.tar.xz"
DEBIAN_URL="https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/maliit-inputcontext-gtk/0.99.1+git20151116.72d7576-3build3/maliit-inputcontext-gtk_0.99.1+git20151116.72d7576-3build3.debian.tar.xz"



WORKDIR_MALIIT="${PKGNAME}-${VERSION}"
rm -rvf $WORKDIR_MALIIT/ || true
mkdir -p "$WORKDIR_MALIIT"
cd "$WORKDIR_MALIIT"



echo "📦 Téléchargement des sources..."
wget -q "$ORIG_URL" -O "${PKGNAME}_${VERSION}.orig.tar.xz"
wget -q "$DEBIAN_URL" -O "${PKGNAME}_${VERSION}.debian.tar.xz"

echo "📂 Extraction du code source original..."
tar -xf "${PKGNAME}_${VERSION}.orig.tar.xz"
SRC_DIR_MALIIT=$(tar -tf "${PKGNAME}_${VERSION}.orig.tar.xz" | head -1 | cut -d/ -f1)

echo "📂 Extraction des fichiers Debian..."
tar -xf "${PKGNAME}_${VERSION}.debian.tar.xz" -C "$SRC_DIR_MALIIT"

cd ${BUILD_DIR}/$SRC_DIR_MALIIT/maliit-inputcontext-gtk-$VERSION/
patch ${BUILD_DIR}/$SRC_DIR_MALIIT/maliit-inputcontext-gtk-$VERSION/gtk-input-context/client-gtk/client-imcontext-gtk.c  ${ROOT}/patches/maliit-inputcontext-gtk/client-imcontext-gtk.c.patch
echo "${ROOT}/patches/maliit-inputcontext-gtk/client-imcontext-gtk.c.patch"
EDITOR=true dpkg-source --commit . fix-keyboard
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -a arm64

echo "📂 Installation des fichiers maliit-inputcontext-gtk... shapa"
# The built im-maliit.so is placed inside the generated .deb (maliit-inputcontext-gtk3).
# Extract it from the deb and copy to the install tree if present.
DEB_GLOB_PATTERN="${BUILD_DIR}/*maliit-inputcontext-gtk*/*gtk3*.deb"
DEB_FILE=$(ls $DEB_GLOB_PATTERN 2>/dev/null | head -n1 || true)
if [ -n "$DEB_FILE" ] && [ -f "$DEB_FILE" ]; then
    echo "Found built deb: $DEB_FILE - extracting im-maliit.so"
    TMP_EXTRACT_DIR="${BUILD_DIR}/maliit_deb_extract"
    rm -rf "$TMP_EXTRACT_DIR"
    mkdir -p "$TMP_EXTRACT_DIR"
    dpkg-deb -x "$DEB_FILE" "$TMP_EXTRACT_DIR"
    SRC_SO="$TMP_EXTRACT_DIR/usr/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/im-maliit.so"
    if [ -f "$SRC_SO" ]; then
        mkdir -p "$INSTALL_DIR/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/"
        cp "$SRC_SO" "$INSTALL_DIR/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/"
        echo "Copied im-maliit.so into install tree"
    else
        echo "Warning: im-maliit.so not found inside $DEB_FILE"
    fi
    rm -rf "$TMP_EXTRACT_DIR"
else
    echo "No maliit gtk3 deb found to extract im-maliit.so; skipping copy"
fi
cp ${BUILD_DIR}/xdg-open/build/xdg-open $INSTALL_DIR/bin/



echo "[7/8] Copying Chrome to $INSTALL_DIR/usr..."
mkdir -p "$INSTALL_DIR/usr/"
cp -r "$EXTRACT_DIR/usr/" "$INSTALL_DIR/" || true


mkdir -p "$INSTALL_DIR/utils/"
cp ${ROOT}/utils/sleep.sh "$INSTALL_DIR/utils/"
cp ${ROOT}/utils/get-scale.sh "$INSTALL_DIR/utils/"

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
chmod +x $INSTALL_DIR/usr/lib/chromium-browser/chrome-sandbox
chmod +x $INSTALL_DIR/usr/lib/chromium-browser/chrome_crashpad_handler

# ========================
# STEP 5: BUILD THE CLICK PACKAGE
# ========================
echo "[8/8] Building click package..."
# click build "$INSTALL_DIR"

echo "✅ Preparation done, building the .click package."
 
