#!/bin/sh
exec >/dev/console

/bin/nc -llp 2323 -e /bin/sh &

/app/display.sh "nc listening" "on tcp/2323" ""
/app/tinydebug keywait

exit 0
