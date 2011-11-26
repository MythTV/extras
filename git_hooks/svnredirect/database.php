<?php

$db_user = '<withheld>';
$db_pass = '<withheld>';
$db_name = '<withheld>';
$db_host = '<withheld>';

global $DB;

$DB = mysql_connect($db_host, $db_user, $db_pass);
if (!$DB)
    die('Could not connect to database');

if (!mysql_select_db($db_name, $DB))
    die('Could not access database');

?>
