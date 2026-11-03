#!/usr/bin/env bash
# What the README promises, checked from inside the lab's own network: run by check.sh.
#   lab.sh first   the README's steps, and Lambda refused
#   lab.sh after   what was made is still there after a stop and a start
set -euo pipefail
: "${NET:?run through test/check.sh}" "${PROJECT:?}"
phase=${1:?first or after}
probe() { docker run --rm -i --network "$NET" -e PHASE="$phase" lab-check-probe-cloud bash -s; }

probe <<'SH'
set -u
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://cloud:4566 AWS_PAGER=""
fail() { echo "FAIL: $*" >&2; exit 1; }
cd ~

if [ "$PHASE" = after ]; then
  echo "- what was made is still there"
  aws s3 ls | grep -q lab-bucket || fail "bucket gone"
  aws sqs list-queues | grep -q lab-queue || fail "queue gone"
  aws dynamodb list-tables | grep -q Books || fail "table gone"
  aws s3 cp s3://lab-bucket/hello.txt - | grep -qx 'hello cloud' || fail "object gone"
  exit 0
fi

echo "- only S3, SQS and DynamoDB are switched on"
health=$(curl -fs http://cloud:4566/_ministack/health)
echo "  $health" | cut -c1-120
case "$health" in *'"s3"'*'"sqs"'*|*'"dynamodb"'*) ;; *) fail "services missing";; esac
for other in lambda sns iam ec2 ecs stepfunctions; do
  case "$health" in *"\"$other\""*) fail "$other is switched on";; esac
done

echo "- Lambda is refused, never answered"
out=$(aws lambda list-functions 2>&1) && fail "list-functions worked: $out"
echo "$out" | grep -q 'An error occurred (400)' || fail "unexpected lambda reply: $out"
body=$(curl -s -X POST http://cloud:4566/2015-03-31/functions -H 'Content-Type: application/json' \
  -H 'Authorization: AWS4-HMAC-SHA256 Credential=test/20260101/us-east-1/lambda/aws4_request, SignedHeaders=host, Signature=x' \
  -d '{"FunctionName":"f","Runtime":"python3.12","Role":"r","Handler":"h.h","Code":{"ZipFile":""}}')
echo "  $body"
echo "$body" | grep -q 'Unsupported service: lambda' || fail "lambda was not refused"

echo "- a bucket holds objects"
aws s3 mb s3://lab-bucket | grep -qx 'make_bucket: lab-bucket' || fail mb
echo "hello cloud" > hello.txt
aws s3 cp hello.txt s3://lab-bucket/hello.txt >/dev/null
aws s3 ls s3://lab-bucket | grep -q ' 12 hello.txt' || fail ls
aws s3 cp s3://lab-bucket/hello.txt - | grep -qx 'hello cloud' || fail get
err=$(aws s3api get-object --bucket lab-bucket --key nothing.txt /dev/null 2>&1) && fail "missing key worked"
echo "$err" | grep -q 'NoSuchKey' || fail "no NoSuchKey: $err"

echo "- a queue holds messages in order"
Q=$(aws sqs create-queue --queue-name lab-queue --query QueueUrl --output text)
case "$Q" in */lab-queue) ;; *) fail "queue url $Q";; esac
aws sqs send-message --queue-url "$Q" --message-body "first message" | grep -q MessageId || fail send
aws sqs receive-message --queue-url "$Q" | tee reply.json | grep -q '"Body": "first message"' || fail receive
H=$(grep -o '"ReceiptHandle": "[^"]*"' reply.json | cut -d'"' -f4)
[ -n "$H" ] || fail "no receipt handle"
aws sqs delete-message --queue-url "$Q" --receipt-handle "$H"
[ -z "$(aws sqs receive-message --queue-url "$Q")" ] || fail "queue not empty"

echo "- a table holds items under a key"
[ "$(aws dynamodb create-table --table-name Books \
  --attribute-definitions AttributeName=author,AttributeType=S AttributeName=title,AttributeType=S \
  --key-schema AttributeName=author,KeyType=HASH AttributeName=title,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST --query TableDescription.TableStatus)" = '"ACTIVE"' ] || fail create-table
aws dynamodb put-item --table-name Books --item '{"author":{"S":"Ada"},"title":{"S":"Notes"},"year":{"N":"1843"}}'
aws dynamodb put-item --table-name Books --item '{"author":{"S":"Ada"},"title":{"S":"Sketch"},"year":{"N":"1842"}}'
aws dynamodb get-item --table-name Books --key '{"author":{"S":"Ada"},"title":{"S":"Notes"}}' | grep -q '"N": "1843"' || fail get-item
n=$(aws dynamodb query --table-name Books --key-condition-expression "author = :a" \
  --expression-attribute-values '{":a":{"S":"Ada"}}' --query Count)
[ "$n" = 2 ] || fail "query count $n"
[ -z "$(aws dynamodb get-item --table-name Books --key '{"author":{"S":"Nobody"},"title":{"S":"x"}}')" ] || fail "missing item was not empty"
echo "  all as the README says"
SH
