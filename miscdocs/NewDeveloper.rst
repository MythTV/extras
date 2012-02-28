NOTE:  This is not yet in effect.  No freaking out.

========================================
Information for the new MythTV developer
========================================

Code of Conduct
---------------

MythTV has a Code of Conduct for all developers.  As a new developer (or one
that hasn't yet done so), you will need to sign this (with a GPG key, see
below), and send the signed copy to: new-developer@mythtv.org.

Git Access
----------

Our code is committed via centralized git repositories at:
 - git@code.mythtv.org:/mythtv
 - git@code.mythtv.org:/mythweb
 - git@code.mythtv.org:/packaging
 - git@code.mythtv.org:/extras
 - git@code.mythtv.org:/nuvexport

These repositories are all mirrored at github.com/MythTV for use by the public,
but be forewarned:  if you commit to github directly, your commits will be
blown away on the next commit to the mythtv repos.

To get commit access to the MythTV repos, you will need to send an ssh public
key (see below) to: new-developer@mythtv.org

Your git username will be either your canonical username (see below), or, if
that is too long or cumbersome, we can use your requested nickname instead.

Mail Aliases
------------

Every developer is given a mail alias in the form:

::

   first initial + last name @mythtv.org

for instance:

::

   ghurlbut@mythtv.org  (for Gavin Hurlbut)

Additionally, if you would like a nickname mapped, please let us know via:
new-developer@mythtv.org.  We will need to know what valid email address this
email should forward to.

Either the canonical mail alias or the nickname mail alias is to be used for
all git commits, and also for generating the GPG key, and will be used for
your git userid and your trac userid.

You will likely want to create a github account as well (not absolutely needed)
and link your canonical and/or nickname mail aliases to that github account.
This will make it look "nicer" on github, but is not a requirement.


Trac Access
-----------

To be added into Trac as a developer, we need an htpasswd line for your 
user.  To create this password (or to change it later), once your git access is
in place, do:

::

    ssh git@code.mythtv.org htpasswd

Your trac username will match your git username.


IRC Cloak
---------

If you are an IRC user, and you would like a "mythtv/developer" cloak, please
indicate your IRC user and desire for a cloak in the template email.



=======
Details
=======

GPG Key
-------

::

  $ gpg --gen-key

      (1) RSA and RSA (default)

      What keysize do you want? (2048)  -- pick 2048 or larger

      Key is valid for? (0) 
      Key does not expire at all
      Is this correct? (y/N) y

      Real name:      -- put your full real name
      Email address:  -- put your MythTV alias email
      Comment:        -- leave blank or put in your IRC nick if you wish

      Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit?  O

      Enter passphrase:   -- pick a passphrase you can remember, but secret
      Repeat passphrase: 

      **WAIT**  it helps to put in random keystrokes etc, especially if you
      have no entropy-generation daemon running on the box.

      gpg: key 950462A3 marked as ultimately trusted
      public and secret key created and signed.

NOTE: your key number will be different.  I will use this one as an example
for further steps.

::

  $ gpg --keyserver keyserver.ubuntu.com --send-key 0x950462A3

NOTE: you do not need to use ubuntu's keyserver as long as you use one in the
same network of keyservers.

Now, fill in the key number in the template email.  Once we process your email,
we will sign your key.  It can be used before this, but to update your keyring
to include the signature, you will need to do:

::

  $ gpg --keyserver keyserver.ubuntu.com --recv-key 0x920452A3

This will update your keychain with the signature we added.  Should you wish to 
sign a key for someone else (please make sure by all means possible that it
really is their key!):

::

  $ gpg --keyserver keyserver.ubuntu.com --recv-key 0xDEADBEEF
  $ gpg --edit-key 0xDEADBEEF
      Command> trust
      Your decision? -- fill in your trust level for the signature
      Command> quit
  $ gpg --keyserver keyserver.ubuntu.com --send-key 0xDEADBEEF

Now, you can use your key to sign the code of conduct to attach to the mail
to new-developer@mythtv.org

::

  $ gpg --clearsign codeofconduct.txt

Please attach codeofconduct.txt.asc to your email.

SSH Key
-------

::

  $ ssh-keygen -t dsa -b 2048     --- you can use RSA instead if you wish

Paste in the .pub file generated into the template email.  Be careful not to
change it in any way.

If you have more than one development box and want separate keys on each,
please send all the public keys you wish to have access with.  This is not an
issue.


Git setup
---------
 - please use git 1.6 or newer
 - at some point, we may begin enforcing that the correct email is being used
   at commit time, but right now, it's on the honor system.
 - please do:

::

  $ git config --global user.name "Full Name"
  $ git config --global user.email canonicalalias@mythtv.org

