#!/bin/bash
set -e

cd fxtran

git apply --verbose - <<EOF
diff --git a/makefile b/makefile
index 27f20e5..aa82d25 100644
--- a/makefile
+++ b/makefile
@@ -3,10 +3,6 @@ export ROOT=\$(shell pwd)
 
 all: 
 	cd src && \$(MAKE)
-	cd perl5 && \$(MAKE)
-	cd python3 && \$(MAKE)
-	@mkdir -p share/man/man1
-	@LD_LIBRARY_PATH=lib ./bin/fxtran -help-pod | pod2man -n fxtran -r "" -c "" | gzip -c > share/man/man1/fxtran.1.gz
 
 clean: 
 	cd src && make clean
diff --git a/src/makefile b/src/makefile
index d591f53..be273a1 100644
--- a/src/makefile
+++ b/src/makefile
@@ -14,9 +14,10 @@ endif
 
 all: \$(TOP)/bin/fxtran
 
-\$(TOP)/bin/fxtran: FXTRAN_ALPHA.h fxtran.o \$(TOP)/lib/libfxtran.so.0
+\$(TOP)/bin/fxtran: FXTRAN_ALPHA.h fxtran.o \$(OBJ)
+	cd cpp && make
 	@mkdir -p ../bin
-	\$(CC) -o \$(TOP)/bin/fxtran fxtran.o \$(RPATH) -L\$(TOP)/lib -lfxtran \$(LDFLAGS)
+	\$(CC) -static -o \$(TOP)/bin/fxtran fxtran.o \$(OBJ) cpp/*.o
 
 \$(TOP)/lib/libfxtran.so.0: \$(OBJ)
 	cd cpp && make
EOF

make clean
make

cp bin/fxtran ../autoload/fortran/fxtran
