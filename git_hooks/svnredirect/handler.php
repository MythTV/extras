<?php

require_once('defines.php');
require_once('database.php');

$result = False;

if ( count($Path) != 1 ) {
    require_once('help.php');
    exit;
}

$revision = $Path[0];

if ( ($revision > 27420) || ($revision < 1) ) {
    require_once('help.php');
    exit;
}

$result = mysql_query("SELECT repo, branch, sha1 FROM plugin_svngit WHERE svnid=".$revision, $DB);

$rowcount = mysql_num_rows($result);
if ( $rowcount == 0 )
    require_once('help.php');
elseif ( $rowcount > 1 )
    require_once('multiple.php');
else
    require_once('redirect.php');
?>
