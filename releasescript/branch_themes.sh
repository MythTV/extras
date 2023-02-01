#!/bin/bash

if [ "$1" == "" ] 
then
    echo "Usage:  $0 releasetag"
    echo ""
    exit 1
fi

if [[ $1 == v* ]]
then
    echo "Bad releasetag. Use only numbers, like '33'"
    echo ""
    exit 1
fi

RELEASEP=$1

if [ -d themes ] ; then
    echo "Removing old themes directory"
    rm -rf themes > /dev/null
fi

echo "Creating themes directory"
mkdir themes > /dev/null

pushd themes > /dev/null

REPOS=(
    "git@github.com:MythTV-Themes/Arclight.git"
    "git@github.com:MythTV-Themes/Mythbuntu.git"
    "git@github.com:MythTV-Themes/Steppes.git"
    "git@github.com:MythTV-Themes/Steppes-large.git"
    "git@github.com:MythTV-Themes/blue-abstract-wide.git"
    "git@github.com:MythTV-Themes/Functionality.git"
    "git@github.com:MythTV-Themes/LCARS.git"
    #"git@github.com:paul-h/MythCenterXMAS-wide.git"
    #"git@github.com:paul-h/MythCenterXMASKIDS-wide.git"
)

for REPO in ${REPOS[@]}
do
    BASE=$(basename $REPO .git)
    echo "###"
    echo "Checking out ${BASE} theme"

    git clone ${REPO} > /dev/null 2>&1
    pushd ${BASE} >> /dev/null
    BRANCHNAME="origin/fixes/${RELEASEP}"
    REMOTENAME=$(git branch -l -r ${BRANCHNAME})
    if [[ "$REMOTENAME" ==  *"fixes"* ]] ; then
       echo "${BRANCHNAME} exists"
    else
       echo "Creating branch ${BRANCHNAME}"
       git push origin HEAD:refs/heads/fixes/${RELEASEP}
    fi

    echo "###"
    echo ""
    popd >> /dev/null
done

popd > /dev/null
