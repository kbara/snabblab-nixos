with (import ../lib {});

let
  defaults = {
    require = [
      ./../modules/lab-configuration.nix
    ];
  };
in {
  network.description = "Snabb Lab machines";

  lugano-1 = { config, pkgs, lib, ... }: defaults // {
      environment.variables = PCIAssignments.lugano;

      # custom NixOS options here
  };
  lugano-2 = { config, pkgs, lib, ... }: defaults // {
      environment.variables = PCIAssignments.lugano;

      # custom NixOS options here
  };
  lugano-3 = { config, pkgs, lib, ... }: defaults // {
      environment.variables = PCIAssignments.lugano;

      # custom NixOS options here
  };
  lugano-4 = { config, pkgs, lib, ... }: defaults // {
      environment.variables = PCIAssignments.lugano;

      # custom NixOS options here
  };
  davos = { config, pkgs, lib, ... }: defaults // {
      # custom NixOS options here
      services.snabb_bot.environment =
        ''
          export SNABB_TEST_IMAGE=eugeneia/snabb-nfv-test-vanilla
          export SNABB_PCI0=0000:03:00.0
          export SNABB_PCI1=0000:03:00.1
          export SNABB_PCI_INTEL0=0000:03:00.0
          export SNABB_PCI_INTEL1=0000:03:00.1
          export SNABB_PCI_INTEL1G0=0000:01:00.0
          export SNABB_PCI_INTEL1G1=0000:01:00.1
        '';
      imports = [ ./../modules/snabb_bot.nix ./../modules/snabb_doc.nix ];
  };
  grindelwald = { config, pkgs, lib, ... }: defaults // {
      # custom NixOS options here

      # OpenStack requirements
      boot.extraModprobeConfig = "options kvm-intel nested=y";
      boot.kernelModules = [ "pci-stub" ];
      boot.kernelParams = lib.mkForce [ "intel_iommu=on" "hugepages=4096" ];
      boot.blacklistedKernelModules = [ "ixgbe" ];
  };
  interlaken = { config, pkgs, lib, ... }: defaults // {
      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/8AB0-B6D9";
        fsType = "vfat";
      };

      # custom NixOS options here
  };

  # Hydra (CI) servers

  murren-1 = defaults;
  murren-2 = defaults;
  murren-3 = defaults;
  murren-4 = defaults;
  murren-5 = defaults;
  murren-6 = defaults;
  murren-7 = defaults;
  murren-8 = defaults;
  murren-9 = defaults;
  murren-10 = defaults;
}

