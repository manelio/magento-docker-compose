<?php
$uri = $_SERVER['DOCUMENT_URI'];
$xhroot = '/opt/xhprof/xhprof_html';

$prefix = '/xhprof';

$contentTypes = [
	'css' => function($file = false) {
		header("Content-Type: text/css");
    	$file && header("Content-Length: " . filesize($file));
	},
	'js' => function($file) {
		header("Content-Type: text/javascript");
    	$file && header("Content-Length: " . filesize($file));
	},
];

if (strpos($uri, $prefix) !== 0) {
	die();
}

$uri = substr($uri, strlen($prefix));
$pi = pathinfo($uri);
$ext = strtolower($pi['extension']);

$lookFor = $xhroot . $uri;

if (in_array($ext, ['js', 'css', 'jpg', 'png']) && file_exists($lookFor)) {
	if (isset($contentTypes[$ext])) {
		$contentTypes[$ext]($lookFor);
	}
	readfile($lookFor);
} else if (in_array($ext, ['php']) && file_exists($lookFor)) {
	include($lookFor);
} else if (is_dir($lookFor) && file_exists($lookFor . '/index.php')) {
	include($lookFor . '/index.php');
}
