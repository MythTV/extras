<?php
$row = mysql_fetch_assoc($result);

header("HTTP/1.1 301 Moved Permanently");
header("Location: http://github.com/MythTV/{$row['repo']}/commit/{$row['sha1']}")
?>

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
echo "You are seeing this page because your browser does not properly handle HTTP/301 redirects.  Please continue to <a href='http://github.com/MythTV/{$row['repo']}/commit/{$row['sha1']}'>Github</a>...\n";
?>
</body>
