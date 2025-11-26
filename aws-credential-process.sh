#!/bin/bash

# AWS Credential Process Script
# Reads temporary AWS credentials from a file and outputs them in the format
# expected by AWS CLI's credential_process configuration.

set -euo pipefail

# Default credentials file path - can be overridden with environment variable
CREDENTIALS_FILE="${AWS_CREDENTIALS_FILE:-/mnt/aws-creds/credentials.json}"

# Check if credentials file exists
if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    echo "Error: Credentials file not found at $CREDENTIALS_FILE" >&2
    echo "Set AWS_CREDENTIALS_FILE environment variable to specify a different path" >&2
    exit 1
fi

# Check if credentials file is readable
if [[ ! -r "$CREDENTIALS_FILE" ]]; then
    echo "Error: Cannot read credentials file at $CREDENTIALS_FILE" >&2
    exit 1
fi

# Read and validate the credentials file
if ! credentials=$(cat "$CREDENTIALS_FILE" 2>/dev/null); then
    echo "Error: Failed to read credentials file" >&2
    exit 1
fi

# Check if the file contains valid JSON
if ! echo "$credentials" | jq . >/dev/null 2>&1; then
    echo "Error: Credentials file does not contain valid JSON" >&2
    exit 1
fi

# Extract credentials using jq
access_key_id=$(echo "$credentials" | jq -r '.AccessKeyId // .access_key_id // empty')
secret_access_key=$(echo "$credentials" | jq -r '.SecretAccessKey // .secret_access_key // empty')
session_token=$(echo "$credentials" | jq -r '.SessionToken // .session_token // empty')
expiration=$(echo "$credentials" | jq -r '.Expiration // .expiration // empty')

# Validate required fields
if [[ -z "$access_key_id" ]]; then
    echo "Error: AccessKeyId not found in credentials file" >&2
    exit 1
fi

if [[ -z "$secret_access_key" ]]; then
    echo "Error: SecretAccessKey not found in credentials file" >&2
    exit 1
fi

# Check if credentials are expired (if expiration is provided)
if [[ -n "$expiration" ]]; then
    current_time=$(date -u +%s)

    # Try to parse expiration time (support both ISO 8601 and epoch formats)
    if [[ "$expiration" =~ ^[0-9]+$ ]]; then
        # Epoch timestamp
        expiration_time="$expiration"
    else
        # ISO 8601 format - convert to epoch
        if ! expiration_time=$(date -u -d "$expiration" +%s 2>/dev/null); then
            echo "Error: Cannot parse expiration time: $expiration" >&2
            exit 1
        fi
    fi

    if [[ "$current_time" -gt "$expiration_time" ]]; then
        echo "Error: Credentials have expired at $expiration" >&2
        exit 1
    fi
fi

# Output credentials in the format expected by AWS credential_process
output_json="{\"Version\":1,\"AccessKeyId\":\"$access_key_id\",\"SecretAccessKey\":\"$secret_access_key\""

if [[ -n "$session_token" ]]; then
    output_json="$output_json,\"SessionToken\":\"$session_token\""
fi

if [[ -n "$expiration" ]]; then
    output_json="$output_json,\"Expiration\":\"$expiration\""
fi

output_json="$output_json}"

echo "$output_json"
