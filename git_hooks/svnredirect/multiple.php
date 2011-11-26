<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
    <title>MythTV, Open Source DVR</title>
    <!--[if lte IE 6]><link rel="stylesheet" type="text/css" href="/css/ie6.css"><![endif]-->
    <!--[if lt IE 8]><link rel="stylesheet" type="text/css" href="/css/ie.css" ><![endif]-->
    <meta name="description" content="MythTV is a Free Open Source digital video recorder project distributed under the terms of the GNU GPL.">
    <meta name="keywords" content="MythTV,MythWeb,MythMusic,MythVideo,Convergence,Free,DVR,Video Recorder,Digital Video Recorder,VCR,Open Source,GPL,Linux,Mac,Mac OS,MacOS,Device">
</head>


<body>
<?php
echo "Your search of revision <b><i>{$revision}</i></b> has turned up {$rowcount} results:<br>\n";
while ( $row = mysql_fetch_assoc($result) ) {
    echo "&nbsp;&nbsp;&nbsp; <a href='http://github.com/MythTV/".$row['repo']."/commit/".$row['sha1']."'>MythTV/".$row['repo']."/".$row['branch']."/".substr($row['sha1'], 0, 9)."</a><br>\n";
}
?>
</body>
