Description/Instructions:

svn.config

Install this as ~/.subversion/config to auto-set svn mime types and other
revelant properties when you add new files to the repository.

svn.bashrc

Helpful functions for your bashrc file that aid in the creation of svn
branches, tags, etc.  Also includes fix_svn_props to fix svn properties
that were left off or applied incorrectly.

svn_apply_autoprops.py

Needed by the fix_svn_props bashrc function.  I believe this originally
comes from the svn contrib directory.  Applies all of the file-type
properties found in svn.config above.
