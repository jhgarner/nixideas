with import <nixpkgs> { };
let
  pivotGcc =
    derivation rec {
      system = builtins.currentSystem;
      builder = "${util-linux}/bin/unshare";
      args = [ "-Umr" "${bash}/bin/bash" script ];
      name = "pivotGcc";
      src = fetchurl {
        url = "mirror://gcc/releases/gcc-11.2.0/gcc-11.2.0.tar.xz";
        sha256 = "sha256-0I7cU2tUw3KhAQ/2YZ3SdMDxYDqkkhK6IPeqLNo2+os=";
      };
      requires = [ coreutils xz gnused bash gcc11.cc gnugrep gmp.dev gmp gcc11.libc gcc11.libc.bin gcc11.libc.dev gcc11.bintools.bintools mpfr mpfr.dev libmpc gawk file isl texinfo findutils diffutils gnutar ];
      passAsFile = [ "requires" ];
    };
  # Embed the script here instead of in a new file so we can use nix string interpolation.
  script = writeTextFile {
    name = "pivotGccBuilder";
    text = ''
      # TODO We're running as "root" right now which some tools might dislike.

      ${coreutils}/bin/mkdir -p $out
      ${coreutils}/bin/mkdir -p gccfakeroot

      # Pivot root requires that our new root be a mount point
      ${util-linux}/bin/mount --bind gccfakeroot gccfakeroot
      cd gccfakeroot

      # Create the fake FHS
      # TODO make this more complete
      ${coreutils}/bin/mkdir -p nix
      ${coreutils}/bin/mkdir -p dev
      ${coreutils}/bin/mkdir -p usr/bin
      ${coreutils}/bin/mkdir -p usr/lib
      ${coreutils}/bin/mkdir -p usr/include
      ${coreutils}/bin/mkdir -p usr/share
      ${coreutils}/bin/mkdir -p root
      ${coreutils}/bin/ln -s /usr/bin bin
      ${coreutils}/bin/ln -s /usr/lib lib
      ${coreutils}/bin/ln -s /usr/lib lib64
      ${coreutils}/bin/mkdir -p build
      ${coreutils}/bin/mkdir -p out
      ${coreutils}/bin/mkdir old_root
      # TODO something with /etc?

      ${util-linux}/bin/mount --rbind /nix nix
      ${util-linux}/bin/mount --rbind /dev dev
      ${util-linux}/bin/mount --bind $out out

      # Create symlinks from nix directories to our FHS
      for i in $(${coreutils}/bin/cat $requiresPath); do
        ${xorg.lndir}/bin/lndir -silent $i usr/
      done
      export PATH=/usr/bin
      export C_INCLUDE_PATH=/usr/include
      export CPLUS_INCLUDE_PATH=/usr/include
      export LD_LIBRARY_PATH=/usr/lib
      export LIBRARY_PATH=/usr/lib
      export NIX_LDFLAGS=-L/usr/lib

      # TODO when this gets abstracted, figure out how unzipping fits in
      ${xz}/bin/unxz < $src | ${gnutar}/bin/tar x --no-same-owner

      ${util-linux}/bin/pivot_root . old_root

      # TODO don't hardcode the build steps
      cd build
      ../gcc-11.2.0/configure --disable-multilib --enable-languages=c,c++ --disable-bootstrap

      ${gnumake}/bin/make
      ${gnumake}/bin/make install-strip

      ${coreutils}/bin/mv /usr/* /out
    '';
  };
in
pivotGcc
