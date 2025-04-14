#!/bin/bash -eu
# Copyright 2025 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

export FUZZ_INTROSPECTOR_CONFIG=$SRC/fuzz_introspector_exclusion.config
cat > $FUZZ_INTROSPECTOR_CONFIG <<EOF
FILES_TO_AVOID
libass/subprojects
libass/build/subprojects
EOF

# The option `-fuse-ld=gold` can't be passed via `CFLAGS` or `CXXFLAGS` because
# Meson injects `-Werror=ignored-optimization-argument` during compile tests.
# Remove the `-fuse-ld=` and let Meson handle it.
# https://github.com/mesonbuild/meson/issues/6377#issuecomment-575977919
if [[ "$CFLAGS" == *"-fuse-ld=gold"* ]]; then
    export CFLAGS="${CFLAGS//-fuse-ld=gold/}"
    export CC_LD=gold
fi
if [[ "$CXXFLAGS" == *"-fuse-ld=gold"* ]]; then
    export CXXFLAGS="${CXXFLAGS//-fuse-ld=gold/}"
    export CXX_LD=gold
fi

FUZZ_ARGS="-DASS_FUZZMODE=2 -DASSFUZZ_MAX_LEN=8192 -DASSFUZZ_FONTCONFIG_SYSROOT=./fc_sysroot"

meson setup build --wrap-mode=nodownload -Dbuildtype=plain -Ddefault_library=static -Dprefer_static=true \
                  -Dfuzz=enabled -Dfontconfig=enabled -Dasm=disabled -Dlibunibreak=enabled \
                  -Dc_args="$CFLAGS $FUZZ_ARGS" -Dcpp_args="$CXXFLAGS $FUZZ_ARGS" \
                  -Dc_link_args="$CFLAGS" -Dcpp_link_args="$CXXFLAGS" \
                  -Dfuzz-link-args="$LIB_FUZZING_ENGINE" -Dfuzz-link-language=cpp \
                  -Dfreetype2:zlib=disabled \
                  -Dfribidi:deprecated=false -Dfribidi:docs=false -Dfribidi:bin=false -Dfribidi:tests=false \
                  -Dfontconfig:xml-backend=expat
meson compile -C build fuzz

DESTDIR=$OUT/fc_sysroot meson install -C build --tags runtime
curl -L https://github.com/libass/libass-tests/raw/613d615deaa48863ce6bd731762696a186c6fd17/regression/.fonts/FansubBlock-CFF.otf -o $OUT/fc_sysroot/usr/local/share/fonts/FansubBlock-CFF.otf

mv build/fuzz/fuzz $OUT/libass_fuzzer
cp fuzz/ass.dict $OUT/ass.dict

cp $SRC/*.options $OUT/
