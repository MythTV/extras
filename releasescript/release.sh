#!/bin/bash

if [ "$1" == "" ] 
then
    echo "Usage:  $0 releasetag"
    echo ""
    exit 1
fi

RELEASEP=$1

echo "Creating release directory"
mkdir release > /dev/null

echo "Checking git statuses (you need to be on the correct branch, and able to commit)"
pushd mythtv > /dev/null
pushd mythtv > /dev/null
git status
read -p "Continue? " yes
if [ .$yes. == .n. -o .$yes. == .N. ] ; then exit 1 ; fi
popd > /dev/null
popd > /dev/null

pushd mythweb > /dev/null
git status
read -p "Continue? " yes
if [ .$yes. == .n. -o .$yes. == .N. ] ; then exit 1 ; fi
popd > /dev/null

# The VERSION file is used to fill in --version for non-git builds
pushd mythtv > /dev/null
pushd mythtv > /dev/null
echo "Fixing VERSION file"
echo SOURCE_VERSION='"v'$RELEASEP'"' > VERSION
git add VERSION
git commit -m "Setting VERSION to v$RELEASEP"
git push origin

echo "Tagging MythTV v$RELEASEP"
git tag -a -f -m "Tagging release $RELEASEP" v$RELEASEP
git push -f origin v$RELEASEP

echo "Archiving MythTV v$RELEASEP"
pushd mythtv > /dev/null
git archive --format=tar --prefix mythtv-$RELEASEP/ -o ../../release/mythtv-$RELEASEP.tar v$RELEASEP
popd > /dev/null

pushd mythplugins > /dev/null
echo "Archiving MythPlugins v$RELEASEP"
git archive --format=tar --prefix mythplugins-$RELEASEP/ -o ../../release/mythplugins-$RELEASEP.tar v$RELEASEP
popd > /dev/null
popd > /dev/null

pushd mythweb > /dev/null
echo "Tagging MythWeb v$RELEASEP"
git tag -a -f -m "Tagging release $RELEASEP" v$RELEASEP
git push -f origin v$RELEASEP

echo "Archiving MythWeb v$RELEASEP"
git archive --format=tar --prefix mythplugins-$RELEASEP/mythweb/ -o ../release/mythweb-$RELEASEP.tar v$RELEASEP
popd > /dev/null
# We're appending this to the mythplugins tarball, can't use git archive result directly
pushd release > /dev/null
tar xf mythweb-$RELEASEP.tar
tar --append -f mythplugins-$RELEASEP.tar mythplugins-$RELEASEP
rm -rf mythplugins-$RELEASEP mythweb-$RELEASEP.tar
popd > /dev/null

echo "Compressing release files"
pushd release > /dev/null
bzip2 -9 mythtv-$RELEASEP.tar
bzip2 -9 mythplugins-$RELEASEP.tar

echo "Computing md5 sums"
md5sum mythtv-$RELEASEP.tar.bz2      > mythtv-$RELEASEP.md5sum
md5sum mythplugins-$RELEASEP.tar.bz2 > mythplugins-$RELEASEP.md5sum

echo "Done, created these output files in release directory:"
ls -lh myth{tv,plugins}-$RELEASEP.{tar.bz2,md5sum}
popd > /dev/null
