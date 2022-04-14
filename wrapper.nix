with import <nixpkgs> { };
let
  root = "/tmp/basefhs4";

  wrap = writeScript "mountAndRun" ''
    # TODO can we put this in a unique directory every time? Can we make it ro and reuse one?
    ${coreutils}/bin/mkdir -p ${root}/nix
    ${coreutils}/bin/mkdir -p ${root}/dev
    ${coreutils}/bin/mkdir -p ${root}/proc
    ${coreutils}/bin/mkdir -p ${root}/sysfs
    ${coreutils}/bin/mkdir -p ${root}/usr
    ${coreutils}/bin/mkdir -p ${root}/home
    ${coreutils}/bin/mkdir -p ${root}/sys
    ${coreutils}/bin/mkdir -p ${root}/old_root

    # TODO modify these so they don't throw errors
    ${coreutils}/bin/ln -s /usr/bin ${root}/bin
    ${coreutils}/bin/ln -s /usr/lib ${root}/lib
    ${coreutils}/bin/ln -s /usr/lib ${root}/lib64

    ${util-linux}/bin/mount --bind ${root} ${root}
    ${util-linux}/bin/mount --rbind /nix ${root}/nix
    ${util-linux}/bin/mount --rbind /dev ${root}/dev
    ${util-linux}/bin/mount --rbind /home ${root}/home
    ${util-linux}/bin/mount --bind /home ${root}/home
    ${util-linux}/bin/mount --bind "$1" ${root}/usr

    ${util-linux}/bin/mount --bind /proc ${root}/proc
    ${util-linux}/bin/mount -t sysfs none ${root}/sys

    # TODO handle nested stuff using something like this
    # ${util-linux}/bin/mount -t overlay overlay -o "lowerdir=/usr:$1" "${root}/usr"

    ${util-linux}/bin/pivot_root ${root} ${root}/old_root

    # TODO don't overwrite path
    export PATH=/usr/bin

    $2 "''${@:3}"
  '';

  unshare = writeScript "unshareWrapper" ''
    ${util-linux}/bin/unshare -Umr ${bash}/bin/bash ${wrap} "$@"
  '';
in
{
  inherit unshare;
}
