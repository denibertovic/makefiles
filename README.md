# Makefile starter templates

The makefiles here are used as starting points when creating new projects.
The examples cover kubernetes, terraform, bare etc.

The repo is meant to be used with [forge](https://github.com/denibertovic/forge) by
running:

    forge fetch -m bare

The above command will fetch the desired template and put it into the current directory
with the filename `Makefile`. If the current directory already has a Makefile, it will
not be trampled, rather it will be renamed to `Makefile.old`.
