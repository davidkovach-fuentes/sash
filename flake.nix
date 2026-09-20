{
  description = "SaSh: Ahead-of-time analysis of shell program effects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs = {
    nixpkgs,
    pyproject-nix,
    uv2nix,
    pyproject-build-systems,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;

    workspace = uv2nix.lib.workspace.loadWorkspace {
      workspaceRoot = ./.;
    };

    overlay = workspace.mkPyprojectOverlay {
      sourcePreference = "wheel";
    };
  in {
    packages = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python312;
          }).overrideScope (
            nixpkgs.lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              overlay

              (final: prev: {
                libdash = prev.libdash.overrideAttrs (old: {
                  nativeBuildInputs =
                    (old.nativeBuildInputs or [])
                    ++ (with pkgs; [
                      gcc
                      gnumake
                      autoconf
                      automake
                      libtool
                    ]);

                  env = (old.env or {}) // {
                    CFLAGS = "-std=gnu17";
                  };
                });
              })
            ]
          );

        sash = pythonSet.mkVirtualEnv
          "sash"
          workspace.deps.default;
      in {
        default = sash;
        inherit sash;
      }
    );

    devShells = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            git
            gnumake
            autoconf
            automake
            libtool
            gcc
            python312
            uv
          ];
        };
      }
    );

    formatter = forAllSystems (
      system:
        nixpkgs.legacyPackages.${system}.alejandra
    );
  };
}
 