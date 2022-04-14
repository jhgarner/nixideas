# TODO Remove this file. The gcc.nix is better.
with import <nixpkgs> { };
let
  hello =
    derivation rec {
      system = builtins.currentSystem;
      builder = "${util-linux}/bin/unshare";
      args = [ "-Umr" "${bash}/bin/bash" (script requires) ];
      name = "testingchroot";
      src = fetchurl {
        url = "mirror://gnu/hello/hello-2.12.tar.gz";
        sha256 = "1ayhp9v4m4rdhjmnl2bq3cibrbqqkgjbl3s7yk2nhlh8vj3ay16g";
      };
      root = fetchTarball {
        url = "https://dl-cdn.alpinelinux.org/alpine/v3.13/releases/x86_64/alpine-minirootfs-3.13.1-x86_64.tar.gz";
      };
      requires = [ coreutils gnused gawk gnumake gcc gnugrep autoconf texinfo automake115x binutils-unwrapped gettext git gnutar findutils xz gzip find diffutils ];
    };
  script = path: writeText "fakeBuilder" ''
    export PATH=${lib.makeBinPath path}
    mkdir -p root
    mkdir -p root/nix
    mkdir -p root/dev
    mkdir -p root/usr/bin
    mkdir -p root/usr/lib
    mkdir -p root/usr/share
    mkdir -p root/root
    mkdir -p root/bin
    mkdir -p root/build
    mkdir -p root/out
    mkdir -p $out
    ln -s ${bash}/bin/sh root/bin/
    tar -xzf $src -C root/build
    ls -l root/build
    mkdir root/old_root
    ${util-linux}/bin/mount --bind root root
    ${util-linux}/bin/mount --rbind /nix root/nix
    ${util-linux}/bin/mount --rbind /dev root/dev
    ${util-linux}/bin/mount --rbind $out root/out
    # ${util-linux}/bin/findmnt
    cd root
    ${util-linux}/bin/pivot_root . old_root
    cd build/hello-2.12
    # ${strace}/bin/strace gcc ${./test.c}
    ./configure --prefix /usr
    ${gnumake}/bin/make
    ${gnumake}/bin/make install
    mv /usr/* /out
  '';
in
hello
