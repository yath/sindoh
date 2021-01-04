#!/bin/sh

KEY="$(echo -n sindoh024601779U | hexdump -v -e '/1 "%02x"')"
tar -cvjf- update.sh | openssl aes-256-cbc -e -K "$KEY" -iv "$KEY" > _update_rodin_up/update.she
