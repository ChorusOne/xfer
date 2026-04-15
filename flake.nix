{
  description = "xfer - Utility to allow out-of-band sending of arbitrary data";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }:
    let
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      projectOverlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      editableOverlay = workspace.mkEditablePyprojectOverlay {
        root = "$REPO_ROOT";
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python313;
        pyzbarOverlay = final: prev: {
          pyzbar = (final.pkgs.callPackage pyproject-nix.build.hacks { }).nixpkgsPrebuilt {
            from = python.pkgs.pyzbar;
          };
        };
        runtimeLibs = with pkgs; [
          glib
          libGL
          stdenv.cc.cc.lib
          xorg.libxcb
          zbar
          zlib

          # Required for the uv package opencv wheel
          fontconfig
          dejavu_fonts
        ];

        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          }).overrideScope
            (
              pkgs.lib.composeManyExtensions [
                pyproject-build-systems.overlays.wheel
                projectOverlay
                pyzbarOverlay
              ]
            );

        editablePythonSet = pythonSet.overrideScope editableOverlay;

        appVenv = pythonSet.mkVirtualEnv "xfer-env" workspace.deps.default;
        devVenv = editablePythonSet.mkVirtualEnv "xfer-dev-env" workspace.deps.all;
        appWrapped = pkgs.symlinkJoin {
          name = "xfer";
          paths = [ appVenv ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/xfer \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs}
          '';
        };
      in
      {
        packages.default = appWrapped;
        apps.default = flake-utils.lib.mkApp {
          drv = appWrapped;
          exePath = "/bin/xfer";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            devVenv
            pkgs.uv
          ]
          ++ runtimeLibs;

          UV_NO_SYNC = "1";
          UV_PYTHON = editablePythonSet.python.interpreter;
          UV_PYTHON_DOWNLOADS = "never";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeLibs;
          NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeLibs;
          NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
          QT_QPA_FONTDIR = "${pkgs.dejavu_fonts}/share/fonts/truetype";
          XFER_QT_FONTDIR = "${pkgs.dejavu_fonts}/share/fonts/truetype";
          QT_QPA_PLATFORM = "xcb";
          FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";
          FONTCONFIG_PATH = "${pkgs.fontconfig.out}/etc/fonts";

          shellHook = ''
            unset PYTHONPATH
            export REPO_ROOT=$(git rev-parse --show-toplevel)
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:$LD_LIBRARY_PATH"
            export QT_QPA_FONTDIR="${pkgs.dejavu_fonts}/share/fonts/truetype"
            export XFER_QT_FONTDIR="${pkgs.dejavu_fonts}/share/fonts/truetype"
            export QT_QPA_PLATFORM="xcb"
            export FONTCONFIG_FILE="${pkgs.fontconfig.out}/etc/fonts/fonts.conf"
            export FONTCONFIG_PATH="${pkgs.fontconfig.out}/etc/fonts"
            unset QT_STYLE_OVERRIDE
          '';
        };
      }
    );
}
