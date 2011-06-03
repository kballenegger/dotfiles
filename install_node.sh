#!/bin/bash

echo "INSTALLING NODE"

mkdir node
cd node
sudo scp cron:/usr/local/bin/node .
scp cron:/usr/local/bin/node .
sudo mv node /usr/local/bin/node
scp cron:/usr/local/bin/node-waf .
sudo mv node-waf /usr/local/bin/node-waf
scp cron:/usr/local/share/man/man1/node.1 .
sudo mv node.1 /usr/local/share/man/man1/.
scp -r cron:/usr/local/lib/node .
sudo mv node/ /usr/local/lib/node
scp -r cron:/usr/local/include/node .
sudo mv node/ /usr/local/include/node

