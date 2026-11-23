cmd_scripts/conmakehash := clang -Wp,-MMD,scripts/.conmakehash.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89     -I./tools/include    -o scripts/conmakehash scripts/conmakehash.c   

source_scripts/conmakehash := scripts/conmakehash.c

deps_scripts/conmakehash := \
  /usr/include/gentoo/fortify.h \
  /usr/include/gentoo/maybe-stddefs.h \

scripts/conmakehash: $(deps_scripts/conmakehash)

$(deps_scripts/conmakehash):
