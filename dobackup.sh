#!/usr/bin/env sh

set -e

source .env

# default storage class to standard if not provided
S3_STORAGE_CLASS=${S3_STORAGE_CLASS:-STANDARD}

# generate file name for tar
if [ "$BACKUP_NAME_TIMESTAMP" = false ]; then
  echo "BACKUP_NAME_TIMESTAMP is disabled"
  FILE_NAME=/tmp/${BACKUP_NAME}.tar.gz
else
  FILE_NAME=/tmp/${BACKUP_NAME}-$(date "+%Y-%m-%d_%H-%M-%S").tar.gz
fi

# Check if TARGET variable is set
if [ -z "${TARGET}" ]; then
    echo "TARGET env var is not set so we use the default value (/data)"
    TARGET=/data
else
    echo "TARGET env var is set"
fi

# Check if S3_ENDPOINT variable is set
if [ -z "${S3_ENDPOINT}" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

# Check if EXCLUDE_FILES variable is set
if [ -z "${EXCLUDE_FILES}" ]; then
  EXCLUDE_ARGS=""
else
  EXCLUDE_ARGS="--exclude=${EXCLUDE_FILES}"
fi

# Check if IGNORE_ERRORS variable is set
if [ -z "${IGNORE_ERRORS}" ]; then
  IGNORE_ERRORS=""
else
  echo "IGNORE_ERRORS is enabled"
  IGNORE_ERRORS="--ignore-failed-read --ignore-command-error --warning=no-file-changed"
fi

echo "creating archive"
tar -zcvf "${FILE_NAME}" ${IGNORE_ERRORS} ${EXCLUDE_ARGS} "${TARGET}"
echo "uploading archive to S3 [${FILE_NAME}, storage class - ${S3_STORAGE_CLASS}]"
aws s3 ${AWS_ARGS} cp --storage-class "${S3_STORAGE_CLASS}" "${FILE_NAME}" "${S3_BUCKET_URL}"
echo "removing local archive"
rm "${FILE_NAME}"
echo "done"

if [ -n "${WEBHOOK_URL}" ]; then
    echo "notifying webhook"
    curl -m 10 --retry 5 "${WEBHOOK_URL}"
fi
