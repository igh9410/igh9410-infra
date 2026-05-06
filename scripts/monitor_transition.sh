#!/bin/bash
PROD_URL="https://landskipifyai.com/healthcheck"
DEV_URL="https://dev.landskipifyai.com/healthcheck"

echo "Monitoring $PROD_URL and $DEV_URL"
echo "Logging non-200 responses to transition_downtime.log"

while true; do
  PROD_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "$PROD_URL")
  DEV_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "$DEV_URL")
  
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

  if [ "$PROD_CODE" != "200" ]; then
    echo "$TIMESTAMP: PROD Downtime! Status: $PROD_CODE" >> transition_downtime.log
  fi

  if [ "$DEV_CODE" != "200" ]; then
    echo "$TIMESTAMP: DEV Downtime! Status: $DEV_CODE" >> transition_downtime.log
  fi
  
  sleep 0.5
done
