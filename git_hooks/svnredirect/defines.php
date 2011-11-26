<?php

/**
 * $Path is an array of PATH_INFO passed into the script via mod_rewrite or some
 * other lesser means.  It contains most of the information required for
 * figuring out what functions the user wants to access.
 *
 * @global  array   $GLOBALS['Path']
 * @name    $Path
/**/

global $Path;
$Path = '';

if (isset($_SERVER['ORIG_PATH_INFO']) && !isset($_SERVER['FCGI_ROLE']))
    $Path = $_SERVER['ORIG_PATH_INFO'];
elseif (isset($_SERVER['PATH_INFO']))
    $Path = $_SERVER['PATH_INFO'];
elseif (isset($_ENV['PATH_INFO']))
    $Path = $_ENV['PATH_INFO'];
elseif (isset($_GET['PATH_INFO']))
    $Path = $_GET['PATH_INFO'];

// Convert extra whitespace
    $Path = preg_replace('/[\s]+/', ' ', $Path);

// Remove leading slashes
    $Path = preg_replace('/^\/+/', '', $Path);

$Path = explode('/', $Path);

?>
