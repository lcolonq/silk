#!/bin/sh
cd src/ || exit 1;
nix shell nixpkgs#gcc -c make -f Makefile.emacs install
