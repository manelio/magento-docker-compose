location ~* ^/xhprof(?:/(.*))?$ {

    rewrite ^/xhprof$ /xhprof/ permanent;

    fastcgi_pass   fastcgi_backend;

    fastcgi_param  PHP_FLAG  "session.auto_start=off \n suhosin.session.cryptua=off";
    fastcgi_param  PHP_VALUE "memory_limit=756M \n max_execution_time=600";
    fastcgi_read_timeout 600s;
    fastcgi_connect_timeout 600s;

    fastcgi_index  index.php;
    fastcgi_param  SCRIPT_FILENAME  /usr/local/share/php/xhproxy.php;
    include        fastcgi_params;
}