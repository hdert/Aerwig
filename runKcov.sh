#!/bin/dash

rm -r zig-cache
rm -r kcov-output
zig build test &&
for i in zig-cache/o/*/test
do
    kcov --exclude-path=/usr/lib/zig/lib/ kcov-output $i
done
xdg-open kcov-output/index.html 