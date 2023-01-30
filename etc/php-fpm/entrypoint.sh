#!/bin/bash
while ! ( ls $WAIT_FOR_FILES >/dev/null 2>&1 ); do echo "waiting for $WAIT_FOR_FILES ..."; sleep 1; done;

asyncRun() {
    "$@" &
    pid="$!"
    trap "echo 'Stopping PID $pid'; kill -SIGTERM $pid" SIGINT SIGTERM SIGQUIT
    while kill -0 $pid > /dev/null 2>&1; do wait; done
}

asyncRun docker-php-entrypoint php-fpm
