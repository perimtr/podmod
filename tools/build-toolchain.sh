#!/bin/bash
# Build Rockbox's ARM cross-compiler (binutils 2.38 + GCC 9.5.0, arm-elf-eabi)
# into tools/arm, following src/rockbox/tools/rockboxdev.sh for Apple Silicon.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFIX=$ROOT/tools/arm
DL=$ROOT/src/toolchain/dl
BUILD=$ROOT/src/toolchain/build
PATCHES=$ROOT/src/rockbox/tools/toolchain-patches
GNU=https://mirrors.kernel.org/gnu
J=$(sysctl -n hw.physicalcpu)
mkdir -p "$DL" "$BUILD" "$PREFIX"
export PATH="$PREFIX/bin:$PATH"

get() { [ -s "$DL/$1" ] || { echo "== download $1"; curl -fL -A curl -o "$DL/$1.part" "$2/$1" && mv "$DL/$1.part" "$DL/$1"; }; }
get binutils-2.38.tar.gz $GNU/binutils
get gcc-9.5.0.tar.gz $GNU/gcc/gcc-9.5.0
get gmp-6.1.2.tar.bz2 $GNU/gmp
get mpfr-4.1.1.tar.gz $GNU/mpfr
get mpc-1.2.1.tar.gz $GNU/mpc
get isl-0.18.tar.bz2 https://gcc.gnu.org/pub/gcc/infrastructure

libs() { # link support libraries into the current source tree
  for l in "$@"; do
    case $l in
      gmp) f=gmp-6.1.2.tar.bz2 ;; mpfr) f=mpfr-4.1.1.tar.gz ;; mpc) f=mpc-1.2.1.tar.gz ;; isl) f=isl-0.18.tar.bz2 ;;
    esac
    tar xf "$DL/$f"; ln -s "${f%.tar.*}" "$l"
  done
}
build() { # name version "patches" "libs" configure-args...
  local name=$1 ver=$2 patches=$3 needs=$4; shift 4
  [ -e "$BUILD/.done-$name" ] && { echo "== $name already built"; return; }
  echo "== $name $ver: extract"
  cd "$BUILD"; rm -rf "$name-$ver" "build-$name"
  tar xf "$DL/$name-$ver.tar.gz"
  cd "$name-$ver"
  for p in $patches; do echo "== patch $p"; patch -p1 < "$PATCHES/$p"; done
  libs $needs
  mkdir "$BUILD/build-$name"; cd "$BUILD/build-$name"
  echo "== $name: configure"
  CFLAGS='-U_FORTIFY_SOURCE -fgnu89-inline -fcommon -O2' CXXFLAGS='-std=gnu++03 -fbracket-depth=512' \
    "../$name-$ver/configure" --target=arm-elf-eabi --prefix="$PREFIX" --disable-docs "$@" > "$BUILD/$name-configure.log" 2>&1
  echo "== $name: make"
  make -j"$J" MAKEINFO=true > "$BUILD/$name-make.log" 2>&1
  echo "== $name: install"
  make install MAKEINFO=true > "$BUILD/$name-install.log" 2>&1
  touch "$BUILD/.done-$name"
  cd "$BUILD"; rm -rf "$name-$ver" "build-$name"
}
build binutils 2.38 "apple_silicon-zlib.patch" "gmp isl" --disable-nls --disable-werror
build gcc 9.5.0 "rockbox-multilibs-noexceptions-arm-elf-eabi-gcc-9.5.0.diff apple_silicon.patch apple_silicon-zlib.patch gcc-libcpp17.patch" "gmp mpfr mpc isl" \
  --enable-languages=c --disable-libssp --disable-nls MAKEINFO=missing
"$PREFIX/bin/arm-elf-eabi-gcc" --version | head -1
echo "TOOLCHAIN OK"
