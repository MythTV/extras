#!/bin/sh

RELEASEP="0.24"
RELEASEM="0-24"

echo "Exporting $RELEASEP repository"
svn export http://svn.mythtv.org/svn/tags/release-$RELEASEM > /dev/null
pushd release-$RELEASEM > /dev/null
echo "Renaming release directories"
mv mythtv      mythtv-$RELEASEP
mv mythplugins mythplugins-$RELEASEP
mv myththemes  myththemes-$RELEASEP
echo 'SOURCE_VERSION="$RELEASEP"' > mythtv-$RELEASEP/VERSION
echo "Taring release files"
tar cf ../mythtv-$RELEASEP.tar      mythtv-$RELEASEP
tar cf ../mythplugins-$RELEASEP.tar mythplugins-$RELEASEP
tar cf ../myththemes-$RELEASEP.tar  myththemes-$RELEASEP
echo "Restoring release directory names"
mv mythtv-$RELEASEP      mythtv
mv mythplugins-$RELEASEP mythplugins
mv myththemes-$RELEASEP  myththemes
echo "Compressing release files"
popd > /dev/null
bzip2 -9 mythtv-$RELEASEP.tar
bzip2 -9 myththemes-$RELEASEP.tar
bzip2 -9 mythplugins-$RELEASEP.tar
echo "Computing md5 sums"
md5sum mythtv-$RELEASEP.tar.bz2      > mythtv-$RELEASEP.md5sum
md5sum mythplugins-$RELEASEP.tar.bz2 > mythplugins-$RELEASEP.md5sum
md5sum myththemes-$RELEASEP.tar.bz2  > myththemes-$RELEASEP.md5sum
echo "Done, created these output files:"
ls -l myth{tv,plugins,themes}-$RELEASEP.{tar.bz2,md5sum}
