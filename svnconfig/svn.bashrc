#!/bin/bash

#
# Subversion helpers for bash
#

# Aliases to `svn diff` that show things via the colordiff app (which you may
# need to install via apt), both with and without whitespace changes shown.
  alias svndiff='svn diff --diff-cmd=colordiff'
  alias svndiffw='svn diff --diff-cmd=colordiff -x "-buw"'

# If you don't like color (which doesn't work well to pipe into a file to
# send out for code review, you could use something like the following, which
# will also add 10 extra lines of context:
#  alias svndiff='svn diff --diff-cmd=diff -x "-U 10"'

# Create a tag in SVN
  function svntag() {
    TAG="$1"
    if [ -z "$TAG" ]; then
      echo "Usage:  svntag NEW_TAG_NAME"
      return 1
    fi
    INFO=`svn info . | grep ^URL`
    if [[ "$INFO" =~ '((svn\+ssh:.+?)/(trunk|tags|branches)(/([^/]+))?)' ]]; then
      BASE=${BASH_REMATCH[2]}
      TYPE=${BASH_REMATCH[3]}
      CUR=${BASH_REMATCH[1]}
      NEW="$BASE/tags/$TAG"
      echo "Creating tag $TAG:"
      echo "  from:  $CUR"
      echo "  to:  $NEW"
      svn cp "$CUR" "$NEW"
    else
      echo "Could not determine current working path."
      echo "Please make sure you are in your SVN checkout directory."
    fi
  }

# Create a branch in SVN
  function svnbranch() {
    TAG="$1"
    if [ -z "$TAG" ]; then
      echo "Usage:  svnbranch NEW_BRANCH_NAME"
      return 1
    fi
    INFO=`svn info . | grep ^URL`
    if [[ "$INFO" =~ '((svn\+ssh:.+?)/(trunk|tags|branches)(/([^/]+))?)' ]]; then
      BASE=${BASH_REMATCH[2]}
      TYPE=${BASH_REMATCH[3]}
      CUR=${BASH_REMATCH[1]}
      NEW="$BASE/branches/$TAG"
      echo "Creating branch $TAG:"
      echo "  from:  $CUR"
      echo "  to:  $NEW"
      svn cp "$CUR" "$NEW"
      echo "Switching to $TAG"
      svn switch "$NEW"
    else
      echo "Could not determine current working path."
      echo "Please make sure you are in your SVN checkout directory."
    fi
  }

# Switch to a different branch in SVN
  function svnswitch() {
    TAG="$1"
    if [ -z "$TAG" ]; then
      echo "Usage:  svnswitch {BRANCH_NAME,trunk,head}"
      return 1
    fi
    LOWERTAG=`echo $TAG | tr [:upper:] [:lower:]`
    INFO=`svn info . | grep ^URL`
    if [[ "$INFO" =~ '((svn\+ssh:.+?)/(trunk|tags|branches)(/([^/]+))?)' ]]; then
      BASE=${BASH_REMATCH[2]}
      TYPE=${BASH_REMATCH[3]}
      CUR=${BASH_REMATCH[1]}
      if [ "$LOWERTAG" = "trunk" -o "$LOWERTAG" = "head" ]; then
        NEW="$BASE/trunk"
      else
        NEW="$BASE/branches/$TAG"
      fi
      echo "Switching to $TAG"
      svn switch "$NEW"
    else
      echo "Could not determine current working path."
      echo "Please make sure you are in your SVN checkout directory."
    fi
  }

# Fix svn properties for files that came in before my ~/.svn/config was created
  function fix_svn_props() {
  # First, fix the svn:keywords (We need -n 1 because svn craps out if it hits
  # an unversioned file, and won't process any following arguments)
    find . \
      -regex '.+\.\(php\|inc\|pl\|pm\|py\|sh\|js\|css\|html?\|java\|vm\|rb\|rhtml\|rjs\|rxml\|tt\|xml\|sql\)$'    \
      -exec svn ps svn:keywords "Id Date Revision Author HeadURL" {} \+ 2>&1 \
      | grep -v 'is not a working copy'
  # And make sure we have UNIX linefeeds on all files, too.
    find . \
      -regex '.+\.\(csv\|php\|inc\|pl\|pm\|py\|sh\|js\|css\|html?\|java\|vm\|rb\|rhtml\|rjs\|rxml\|tt\|xml\|sql\)$' \
      -exec svn ps svn:eol-style "native" {} \+ 2>&1 \
      | grep -v 'is not a working copy'
  # But not on files that shouldn't have them
    find . \
      -regex '.+\.\(bmp\|gif\|ico\|jpeg\|jpg\|png\|svg\|svgz\|tif\|tiff\|eps\|avi\|mov\|mp3\|smil\|swf\|bz2\|gpgkey\|gtar\|gz\|tar\|tar.bz2\|tar.gz\|tbz\|tgz\|vcf\|zip\|ai\|csv\|doc\|docm\|docx\|dotm\|dotx\|odb\|odc\|odf\|odg\|odi\|odm\|odp\|ods\|odt\|otg\|oth\|otp\|ots\|ott\|pdf\|pdf\|potm\|potx\|ppam\|ppsm\|ppsx\|ppt\|pptm\|pptx\|ps\|psd\|rtf\|xlam\|xls\|xlsb\|xlsm\|xlsx\|xltm\|xltx\)$' \
      -exec svn propdel svn:eol-style {} \+ 2>&1 \
      | grep -v 'is not a working copy'
  # Next, the mime types
    if which svn_apply_autoprops.py &> /dev/null; then
      svn_apply_autoprops.py
    else
      echo "svn_apply_autoprops.py not found in \$PATH"
    fi
  # And now a handful of executable flags
    find . -regex '.+\.\(pl\|py\|sh\)$' -exec svn ps svn:executable on {} \+
    find . -regex '.+\.\(gif\|jpe?g\|png\|txt\|csv\|inc\|pm\|pdf\|php\|class\|java\|js\|css\|html?\|rb\|rhtml\|erb\|vm\|xml\|sql\)$' -exec svn pd svn:executable {} \+
  }

