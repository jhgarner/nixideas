with import <nixpkgs> { };
with import ./wrapper.nix;
let
  gcc = import ./gcc.nix;
  result = derivation {
    system = builtins.currentSystem;
    name = "pivotGccWrapped";
    wrapper = unshare;
    builder = "${bash}/bin/bash";
    args = [ script ];
    requires = [ bash gcc11.libc gcc11.libc.bin gcc11.libc.dev gcc11.bintools.bintools libmpc isl ];
    passAsFile = [ "requires" ];
  };
  # Embed the script here instead of in a new file so we can use nix string interpolation.
  script = writeText "builder.sh" ''
    ${coreutils}/bin/mkdir -p $out/root
    ${coreutils}/bin/mkdir -p $out/raw

    ${xorg.lndir}/bin/lndir -silent ${gcc}/local $out/root

    # Create symlinks from nix directories to our FHS
    for i in $(${coreutils}/bin/cat $requiresPath); do
      ${xorg.lndir}/bin/lndir -silent $i $out/root
    done

    ${python3}/bin/python3 ${./wrap.py} "$out/root" "$out/raw" "$wrapper" "${bash}/bin/bash"
  '';
in
result
