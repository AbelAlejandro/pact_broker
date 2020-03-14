#!/bin/bash

cd example
echo "Installing pact_broker 2.22.0, ordering by publication date"
bundle install >/dev/null 2>&1
bundle exec rackup -p 9292 &
pid=$!

while [ "200" -ne "$(curl -s -o /dev/null  -w "%{http_code}" localhost:9292)" ]; do sleep 0.5; done

curl -X PUT \-H "Content-Type: application/json" -s -d@pact-1.json \
  http://localhost:9292/pacts/provider/Bar/consumer/Foo/version/125 >/dev/null 2>&1

echo && sleep 1

curl -X PUT \-H "Content-Type: application/json" -s -d@pact-2.json \
  http://localhost:9292/pacts/provider/Bar/consumer/Foo/version/124 >/dev/null 2>&1

echo && sleep 1

curl -X PUT \-H "Content-Type: application/json" -s -d@pact-3.json \
  http://localhost:9292/pacts/provider/Bar/consumer/Foo/version/5 >/dev/null 2>&1

echo && sleep 1
echo

echo 'Fetching latest version of pact, expecting version 5, as this is the most recently published version'
curl http://localhost:9292/pacts/provider/Bar/consumer/Foo/latest -s | ruby -e "require 'json'; puts JSON.parse(ARGF.read)['_links']['pb:consumer-version']"
echo

echo 'Fetching matrix'
curl "http://localhost:9292/matrix?q%5B%5Dpacticipant=Foo&q%5B%5Dpacticipant=Bar" -g -H "Accept: text/plain" -s | grep "|"

kill $pid

sleep 5
