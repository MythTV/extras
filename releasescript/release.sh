#!/bin/sh

RELEASEP="0.24.1"

echo "Creating release directory"
mkdir release > /dev/null
pushd mythtv > /dev/null
echo "Archiving MythTV v$RELEASEP"
pushd mythtv > /dev/null
git archive --format=tar --prefix mythtv-$RELEASEP/ -o ../../release/mythtv-$RELEASEP.tar v$RELEASEP
popd > /dev/null
pushd mythplugins > /dev/null
echo "Archiving MythPlugins v$RELEASEP"
git archive --format=tar --prefix mythplugins-$RELEASEP/ -o ../../release/mythplugins-$RELEASEP.tar v$RELEASEP
popd > /dev/null
popd > /dev/null
pushd release > /dev/null
echo "Compressing release files"
bzip2 -9 mythtv-$RELEASEP.tar
bzip2 -9 mythplugins-$RELEASEP.tar
echo "Computing md5 sums"
md5sum mythtv-$RELEASEP.tar.bz2      > mythtv-$RELEASEP.md5sum
md5sum mythplugins-$RELEASEP.tar.bz2 > mythplugins-$RELEASEP.md5sum
echo "Done, created these output files in release directory:"
ls -lh myth{tv,plugins}-$RELEASEP.{tar.bz2,md5sum}
popd > /dev/null
