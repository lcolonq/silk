{
  description = "shell for building sil-q";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      buildInputs = [
        pkgs.gcc
        pkgs.pkgconfig
        pkgs.ncurses
        pkgs.xorg.libX11
      ];
      shell = pkgs.mkShell {
        inherit buildInputs;
      };
    in {
      defaultPackage.x86_64-linux = shell;
      devShell.x86_64-linux = shell;
      packages.x86_64-linux = {
        inherit shell;
      };
    };
}
