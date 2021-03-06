{ pkgs }:

with pkgs;

rec {
  # see https://github.com/snabbco/snabb/blob/master/src/doc/testing.md
  test_env = fetchzip {
    url = "https://s3.eu-central-1.amazonaws.com/snabb/vm-ubuntu-trusty-14.04-dpdk-snabb.tar.gz";
    sha256 = "095m9f77pq770lzd5w46rzqqsgyrv8svkqpgmrd756gswb4gd3x2";
    stripRoot = false;
  };

  mkNixTestEnv = import ./test_env.nix { pkgs = pkgs; };

  PCIAssignments = {
    lugano = {
      SNABB_PCI0 = "0000:01:00.0";
      SNABB_PCI_INTEL0 = "0000:01:00.0";
      SNABB_PCI_INTEL1 = "0000:01:00.1";
    };
    murren = {};
  };

  getPCIVars = hardware:
    let
      pcis = PCIAssignments."${hardware}" or (throw "No such PCIAssignments group as ${hardware}");
    in  pcis  // {
      requiredSystemFeatures = [ hardware ];
    };

  # Function for running commands in environment as Snabb expects tests to run
  mkSnabbTest = { name
                , snabb  # snabb derivation used
                , qemu ? pkgs.qemu  # qemu used in tests
                , checkPhase # required phase for actually running the test
                , hardware  # on what set of hardware should we run this?
                , needsTestEnv ? false  # if true, copies over our testEnv
                , needsNixTestEnv ? false  # if true, copies over our test env
                , testNixEnv ? (mkNixTestEnv {})
                , testEnv ? test_env
                , repeatNum ? null # if the test is repeated more than once, note the repetition
                , isDPDK ? false # set true if dpdk qemu image is used
                , alwaysSucceed ? false # if true, the build will always succeed with a log
                , ...
                }@attrs:
    stdenv.mkDerivation ((getPCIVars hardware) // {
      src = snabb.src;
      name = name + (lib.optionalString (repeatNum != null) "_num=${toString repeatNum}");

      buildInputs = [ git telnet tmux numactl bc iproute which qemu utillinux ];

      SNABB_KERNEL_PARAMS = lib.optionalString needsNixTestEnv
        (if isDPDK
         then "init=${testNixEnv.snabb_config_dpdk.system.build.toplevel}/init"
         else "init=${testNixEnv.snabb_config.system.build.toplevel}/init");

      postUnpack = ''
        patchShebangs .
      '';

      buildPhase = ''
        export PATH=$PATH:/var/setuid-wrappers/
        export HOME=$TMPDIR

        # setup expected directories
        sudo mkdir -p /var/{run,tmp} /hugetlbfs
        sudo mount -t hugetlbfs none /hugetlbfs

        # make sure we reuse the snabb built in another derivation
        ln -s ${snabb}/bin/snabb src/snabb
        sed -i 's/testlog snabb/testlog/' src/Makefile

        mkdir -p $out/nix-support
      '' + lib.optionalString (needsTestEnv || needsNixTestEnv) ''
        mkdir ~/.test_env
        cp --no-preserve=mode -r ${if needsNixTestEnv then testNixEnv else testEnv}/* ~/.test_env/
      '';

      doCheck = true;

      # http://unix.stackexchange.com/questions/14270/get-exit-status-of-process-thats-piped-to-another/73180#73180
      checkPhase =
        lib.optionalString alwaysSucceed ''
          set +o pipefail
        '' + ''${checkPhase}'' +
        lib.optionalString alwaysSucceed ''
          # if pipe failed, note that so it's eaiser to inspect end result
          [ "''${PIPESTATUS[0]}" -ne 0 ] && touch $out/nix-support/failed
          set -o pipefail
      '';

      installPhase = ''
        runHook preInstall

        for f in $(ls $out/* | sort); do
          if [ -f $f ]; then
            echo "file log $f"  >> $out/nix-support/hydra-build-products
          fi
        done

        runHook postInstall
      '';

      meta = {
        inherit repeatNum;
      } // attrs.meta or {};
     } // removeAttrs attrs [ "checkPhase" "meta" "name" ]);

  # runs the benchmark without chroot to be able to use pci device assigning
  mkSnabbBenchTest = { name, times, ... }@attrs:
   let
     snabbTest = lib.makeOverridable mkSnabbTest ({
       name = "snabb-benchmark-${name}";
       benchName = name;
       alwaysSucceed = true;
       # patch needed for Snabb v2016.05 and lower
       testEnvPatch = [(fetchurl {
         url = "https://github.com/snabbco/snabb/commit/e78b8b2d567dc54cad5f2eb2bbb9aadc0e34b4c3.patch";
         sha256 = "1nwkj5n5hm2gg14dfmnn538jnkps10hlldav3bwrgqvf5i63srwl";
       })];
       patchPhase = ''
         patch -p1 < $testEnvPatch || true
       '';
       preInstall = ''
         cp qemu*.log $out/ || true
         cp snabb*.log $out/ || true
       '';
     } // removeAttrs attrs [ "times" ]);
   in buildNTimes snabbTest times;

  # buildNTimes: repeat building a derivation for n times
  # buildNTimes: Derivation -> Int -> [Derivation]
  buildNTimes = drv: n:
    let
      repeatDrv = i: lib.hydraJob (drv.override { repeatNum = i; });
    in map repeatDrv (lib.range 1 n);

   # take a list of derivations and make an attribute set of out their names
  listDrvToAttrs = list: builtins.listToAttrs (map (attrs: lib.nameValuePair (versionToAttribute attrs.name) attrs) list);

  # "blabla-1.2.3" -> "blabla-1-2-3"
  versionToAttribute = version: builtins.replaceStrings ["."] ["-"] version;
}
