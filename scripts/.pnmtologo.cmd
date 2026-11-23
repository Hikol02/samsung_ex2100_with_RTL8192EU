cmd_scripts/pnmtologo := clang -Wp,-MMD,scripts/.pnmtologo.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89     -I./tools/include    -o scripts/pnmtologo scripts/pnmtologo.c   

source_scripts/pnmtologo := scripts/pnmtologo.c

deps_scripts/pnmtologo := \
  /usr/include/gentoo/fortify.h \
  /usr/include/gentoo/maybe-stddefs.h \

scripts/pnmtologo: $(deps_scripts/pnmtologo)

$(deps_scripts/pnmtologo):
