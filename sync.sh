#!/bin/bash

while getopts "s:d:r:p:t:" opt; do
  case ${opt} in
    s)
      export SOURCE=${OPTARG}
      ;;
    d)
      export DEST=${OPTARG}
      ;;
    r)
      export REMOTE=${OPTARG}
      ;;
    p)
      export PUSHBULLET_API_KEY=${OPTARG}
      ;;
    t)
      export PUSHBULLET_TITLE=${OPTARG}
      ;;
    *)
      echo "Invalid parameter(s) or option(s)."
      usage
      exit 1
      ;;
  esac
done

if [ -z ${SOURCE} ] && [ -z ${DEST} ] && [ -z ${PUSHBULLET_API_KEY} ]; then
  echo "
    Incorrect usage:

    ./rclone_sync \
      -s <source> \
      -d <destination> \
      -p <pushbullet_api_key> \
      -t <pushbullet_message_title>
  "
  exit 1
fi

TEMP_LOG_FILE=$(date +%s)-rclone-log.log

/usr/sbin/rclone sync --dry-run --log-file ${TEMP_LOG_FILE} ${SOURCE} ${REMOTE}:${DEST}
FILE_CHANGES=$(cat ${TEMP_LOG_FILE} | \
  grep 'Not [A-Za-z]* as --dry-run' | \
  sed "s/[0-9]*\/[0-9]*\/[0-9]* [0-9]*\:[0-9]*\:[0-9]* //g" | \
  sed "s/: Not//g" | \
  sed "s/ as --dry-run//g" | \
  awk '{t=$1;$1=$NF;$NF=t}1' | \
  sed "s/deleting/Deleting/g" | \
  sed "s/copying/Copying/g")

/usr/sbin/rclone sync ${SOURCE} ${REMOTE}:${DEST}

curl --header "Access-Token: ${PUSHBULLET_API_KEY}" \
  --header "Content-Type: application/json" \
  --data-binary "{\"body\":\"$(echo ${FILE_CHANGES})\",\"title\":\"${PUSHBULLET_TITLE}\",\"type\":\"note\"}" \
  --request POST  https://api.pushbullet.com/v2/pushes

rm -f ${TEMP_LOG_FILE}
