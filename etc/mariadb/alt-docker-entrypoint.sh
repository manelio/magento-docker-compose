#!/bin/bash
while ! ( ls $WAIT_FOR_FILES >/dev/null 2>&1 ); do echo "waiting for $WAIT_FOR_FILES ..."; sleep 1; done;

asyncRun() {
    "$@" &
    pid="$!"
    trap "echo 'Stopping PID $pid'; kill -SIGTERM $pid" SIGINT SIGTERM
    while kill -0 $pid > /dev/null 2>&1; do wait; done
}

cat << EOF > /root/.my.cnf
[client]
user=${MYSQL_USER}
password=$(</shhh/mysql:user.shhh)
EOF

cat << EOF > /docker-entrypoint-initdb.d/grant.sql
GRANT ALL PRIVILEGES on ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
EOF

find /var/lib/mysql -type f -exec touch {} \; && asyncRun docker-entrypoint.sh mysqld