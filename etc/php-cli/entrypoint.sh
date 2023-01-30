#!/bin/zsh
export HOME=/work
export PATH=/opt/bin:$PATH

# echo "Bootstraping ..."
# for file in /local/bootstrap.d/* /local/bootstrap.*.d/*;
#     do [ -f "$file" ] && [ -x "$file" ] && echo "Running $file ..." && sh -c "$file";
# done

tail -f /dev/null &
pid="$!"

trap "echo 'Stopping PID $pid'; kill -SIGTERM $pid" SIGINT SIGTERM

while kill -0 $pid > /dev/null 2>&1; do
    wait
done