#!/bin/bash
DEV_URL="https://dev.landskipifyai.com/"
LOG_FILE="dev_transition.log"

echo "Monitoring $DEV_URL"
echo "Logging to $LOG_FILE"
echo "Timestamp | Status | Version" | tee -a $LOG_FILE

while true; do
  RESPONSE=$(curl -k -s -w "\n%{http_code}" "$DEV_URL")
  HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | head -n -1)
  VERSION=$(echo "$BODY" | grep -Po '"version":\s*"\K[^"]+' || echo "N/A")
  
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

  if [ "$HTTP_STATUS" != "200" ]; then
    echo "$TIMESTAMP | $HTTP_STATUS | DOWN" | tee -a $LOG_FILE
  else
    echo "$TIMESTAMP | $HTTP_STATUS | $VERSION" | tee -a $LOG_FILE
  fi
  
  sleep 1
done
