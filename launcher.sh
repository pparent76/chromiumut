#!/bin/sh

# Setup logging to temporary location


echo "========================================" 
echo "Launcher started at $(date)"
echo "========================================"
echo "PWD: $PWD"
echo "PATH: $PATH"
echo "User: $(whoami)"
echo "UID: $(id)"
export GDK_SCALE=3
export GTK_IM_MODULE=Maliit
export GTK_IM_MODULE_FILE=$PWD/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/immodules.cache
export GDK_BACKEND=x11 
export DISABLE_WAYLAND=1 
export DCONF_PROFILE=/nonexistent
export XDG_CONFIG_HOME=/home/phablet/.config/chromiumut.shapa/
export LD_LIBRARY_PATH=$PWD/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH
export MALIIT_SOCKET_ADDRESS=unix:path=/run/user/32011/maliit
export GTK_MODULES=gail:atk-bridge:maliitplatforminputcontextplugin
export QT_IM_MODULE=maliit
export XMODIFIERS=@im=Maliit
echo "Environment variables set"
echo "GTK_IM_MODULE=$GTK_IM_MODULE"
echo "GTK_IM_MODULE_FILE=$GTK_IM_MODULE_FILE"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

if [ "$DISPLAY" = "" ]; then
    echo "DISPLAY is empty, detecting X11 display..."
    i=0
    while [ -e "/tmp/.X11-unix/X$i" ] ; do 
        i=$(( i + 1 ))
    done
    i=$(( i - 1 ))
    display=":$i"
    export DISPLAY=$display
    echo "Set DISPLAY=$DISPLAY"
else
    echo "DISPLAY already set to: $DISPLAY"
fi

export PATH=$PWD/bin:$PATH
echo "PATH updated: $PATH"

echo "Checking for get-scale.sh..."
if [ -f "./utils/get-scale.sh" ]; then
    echo "get-scale.sh found"
    scale=$(./utils/get-scale.sh 2>/dev/null )
    echo "Scale retrieved: $scale"
else
    echo "ERROR: get-scale.sh not found at ./utils/get-scale.sh"
    scale="1"
fi

dpioptions="--high-dpi-support=1 --force-device-scale-factor=$scale --grid-unit-px=$GRID_UNIT_PX"
gpuoptions="--use-gl=egl --simulate-touch-screen-with-mouse --touch-events=enabled --enable-features=OverlayScrollbar,kEnableQuic,OverlayScrollbarFlashAfterAnyScrollUpdate,OverlayScrollbarFlashWhenMouseEnter --enable-smooth-scrolling  --disable-low-res-tiling --enable-gpu --enable-gpu-rasterization --enable-zero-copy  --adaboost --enable-gpu-msemory-buffer-video-frames  --font-render-hinting=none --disable-font-subpixel-positioning --disable-new-content-rendering-timeout --enable-defer-all-script-without-optimization-hints  --enable-gpu-vsync  --enable-oop-rasterization --enable-accelerated-video-decode"

echo "Options configured"
echo "DPI options: $dpioptions"
echo "GPU options: $gpuoptions"

echo "Checking for Chrome binary..."
if [ -f "./usr/lib/chromium-browser/chrome" ]; then
    echo "Chrome found, launching..."
else
    echo "ERROR: Chrome binary not found at ./usr/lib/chromium-browser/chrome"
fi

echo "Launching background dummy app..."
#Open a dummy qt gui app to release lomiri from its waiting
(utils/sleep.sh; $PWD/bin/xdg-open )&
echo "Dummy app launched in background"

echo "Starting Chrome..."
exec ./usr/lib/chromium-browser/chrome  $dpioptions $gpuoptions