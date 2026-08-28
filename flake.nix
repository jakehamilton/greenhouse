{
  description = "Greenhouse development environment.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          binutils
          gdb
          strace
          file
          coreutils
          python3
          nasm
          xxd
          hexedit
        ];
      };
    };
}
