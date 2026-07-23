# TB RTL pointers

Do **not** copy RTL here. Design sources stay under the repo-root `rtl/` tree.

This directory is reserved for TB-local stubs, bind wrappers, or filelist
snippets that reference `../../rtl/...` without duplicating modules.

Example filelist fragment:

```text
../../rtl/import/rv_dis_pkg.sv
../../rtl/top/risc_dis_unit.sv
```
