#!/usr/bin/env bash

cd /usr/local/gclient
TOKEN=$(node maketoken.js)
echo $TOKEN
websocat -q -n ws://localhost:${CUSTOM_PORT:=3000}/guaclite?token=${TOKEN}
