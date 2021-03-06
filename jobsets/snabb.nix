{ pkgs ? (import <nixpkgs> {})
# which Snabb source directory is used for testing
, snabbSrc ? (builtins.fetchTarball https://github.com/snabbco/snabb/tarball/next)
# what hardware group is used when executing the jobs
, hardware ? "lugano"
# if true, qemu images are built using Nix in lib/test_env.nix
# if false, qemu images are built using Docker in lib/testing.nix
, useNixTestEnv ? true
}:

with pkgs;
with lib;
with vmTools;
with (import ../lib { inherit pkgs; });

rec {
  manual = import "${snabbSrc}/src/doc" {};
  snabb = import "${snabbSrc}" {};
  tests = mkSnabbTest {
    name = "snabb-tests";
    inherit hardware snabb;
    needsTestEnv = !useNixTestEnv;
    needsNixTestEnv = useNixTestEnv;
    checkPhase = ''
      # run tests
      sudo -E make test -C src/ |& tee $out/tests.log

     if grep -q ERROR $out/tests.log; then
         touch $out/nix-support/failed
     else
         echo "All tests passed."
     fi

      # keep the logs
      cp src/testlog/* $out/
      cp src/qemu*.log $out/
    '';
  };
  distro-builds = with diskImages; builtins.listToAttrs (map
    (diskImage: {
       inherit (diskImage) name;
       value = runInLinuxImage (snabb // {
         inherit diskImage;
         name = "${snabb.name}-${diskImage.name}";
       });
    })
    # List of distros that are currently supported according to upstream EOL
    [
      # TODO: fedora22
      fedora23x86_64
      # https://github.com/snabblab/snabblab-nixos/pull/45
      # debian7x86_64
      debian8x86_64
      # https://github.com/snabblab/snabblab-nixos/pull/45
      # ubuntu1204x86_64
      ubuntu1404x86_64
      ubuntu1510x86_64
      ubuntu1604x86_64
      # https://en.opensuse.org/Lifetime
      opensuse132x86_64
      # https://wiki.centos.org/Download
      centos71x86_64
      # See https://github.com/snabbco/snabb/pull/899
      # centos65x86_64
  ]);
}
