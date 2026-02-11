{
  description = "xfer - Utility to allow out-of-band sending of arbitrary data";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python313.override {
          packageOverrides = pyFinal: _pyPrev: {
            opencv4 = pkgs.opencv4.override {
              enablePython = true;
              pythonPackages = pyFinal;
              enableGtk3 = true;
              gtk3 = pkgs.gtk3;
            };
          };
        };
        pythonEnv = python.withPackages (ps: [
          ps.click
          ps.imageio
          ps.numpy
          ps."opencv-python"
          ps.pillow
          ps.pyzbar
          ps.qrcode
        ]);
        xfer-package = python.pkgs.buildPythonApplication {
          pname = "xfer";
          version = "0.0.5";
          format = "pyproject";
          src = self;

          nativeBuildInputs = with python.pkgs; [
            setuptools
            wheel
          ];
          propagatedBuildInputs = [
            python.pkgs.click
            python.pkgs.imageio
            python.pkgs.numpy
            python.pkgs."opencv-python"
            python.pkgs.pillow
            python.pkgs.pyzbar
            python.pkgs.qrcode
          ];

          pythonImportsCheck = [ "xfer" ];
        };

      in
      {
        packages.default = xfer-package;
        apps.default = flake-utils.lib.mkApp { drv = xfer-package; };

        devShells.default = pkgs.mkShell {
          packages = [
            pythonEnv
          ];
        };
      }
    );
}
