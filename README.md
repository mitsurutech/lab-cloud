# AWS S3, SQS and DynamoDB practice with Docker Compose: a cloud computing lab for students

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml)

A ready-made **cloud computing lab** for classrooms, from the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning), where schools and colleges give every student their own databases, containers and terminal in the browser. Each student gets their own practice cloud, [MiniStack](https://github.com/ministackorg/ministack), an emulator that answers the same requests as **Amazon S3, SQS and DynamoDB**. From the terminal beside it they use the real AWS command line to **make a bucket and store an object, send, receive and delete a queue message, and put, get and query items in a table**, with nothing to install and no AWS account to open or be billed on.

It is one `docker-compose` file, `compose.yaml`, and it runs the same on your own machine as it does on the platform, where every copy has no way out to the internet. It is an **emulator, not AWS**.

## What is in it

| Service | Image | Memory | What it is |
| --- | --- | --- | --- |
| `cloud` | [`ministackorg/ministack:1.4.8`](https://hub.docker.com/r/ministackorg/ministack) | 256 MB | MiniStack with only S3, SQS and DynamoDB switched on |

The one setting that matters is `SERVICES: s3,sqs,dynamodb`. MiniStack then answers those three and refuses every other service with `Unsupported service`. **Lambda is deliberately not one of them**: its functions would run a student's own code inside the stack's container, as root. `aws lambda list-functions` ends in an error, and `test/check.sh` checks that it does. State is kept in a named volume (`PERSIST_STATE`, `S3_PERSIST`), so buckets, queues and tables are still there after the lab is stopped and started. The stack checks no password, so the lesson gives the command line a made-up key. The image is MiniStack's own, MIT licensed, run unmodified and pinned to a version (never `latest`). It used about 75 MB at its peak while the commands below were run, and has 256 MB.

## Using it on the platform

Make a task of type **Lab**, choose **In a GitHub repository** and give `https://github.com/mitsurutech/lab-cloud` with the branch `main`; the compose file is the default, `compose.yaml`. Fork it first to change it. Publish, and every student's copy starts from the commit you published. To try it first, open the [container page](https://mitsurutech.co.uk/container), find **Cloud** in **Sample labs** and press Start. A free account is needed for every lab except the Git and SQL ones.

The help manual has a [page for this lab](https://mitsurutech.co.uk/help/lab-cloud) and a [guide to container labs](https://mitsurutech.co.uk/help/labs): what a compose file may say, how much memory a copy gets, and how teachers watch and take over a student's terminal. The lab goes with the Cloud computing practice module of the [Learning Platform](https://mitsurutech.co.uk/learning), whose assignments are Python over captured answers and need no lab.

No college account yet? [Your first year is free](https://mitsurutech.co.uk/pricing) for up to 50 students, and [signing up](https://mitsurutech.co.uk/signup) takes an email address.

## Running it on your own machine

You need Docker with the Compose plugin. `local.yaml` publishes the port on `127.0.0.1` only.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Then point your own AWS command line at it with `AWS_ENDPOINT_URL=http://localhost:4566`, the made-up key and region below, and the same commands. Stop it with `Ctrl-C` and remove it with `docker compose -f compose.yaml -f local.yaml down -v`.

## Working through it

In the lab's terminal, which reaches the stack by its service name, `cloud`. Each step prints what the comment says it will: `make_bucket: lab-bucket`, then `hello cloud` read back, then an error naming `NoSuchKey`; a message with its `Body` that is then deleted; `"ACTIVE"`, then an item with its values wrapped in types (`S` text, `N` number), then `Count` `2`.

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://cloud:4566
aws s3 mb s3://lab-bucket
echo "hello cloud" | aws s3 cp - s3://lab-bucket/hello.txt
aws s3 cp s3://lab-bucket/hello.txt -
aws s3api get-object --bucket lab-bucket --key nothing.txt /dev/null
Q=$(aws sqs create-queue --queue-name lab-queue --query QueueUrl --output text)
aws sqs send-message --queue-url $Q --message-body "first message"
aws sqs receive-message --queue-url $Q | tee reply.json
H=$(grep -o '"ReceiptHandle": "[^"]*"' reply.json | cut -d'"' -f4)
aws sqs delete-message --queue-url $Q --receipt-handle "$H"
aws dynamodb create-table --table-name Books --attribute-definitions AttributeName=author,AttributeType=S AttributeName=title,AttributeType=S --key-schema AttributeName=author,KeyType=HASH AttributeName=title,KeyType=RANGE --billing-mode PAY_PER_REQUEST --query TableDescription.TableStatus
aws dynamodb batch-write-item --request-items '{"Books":[{"PutRequest":{"Item":{"author":{"S":"Ada"},"title":{"S":"Notes"},"year":{"N":"1843"}}}},{"PutRequest":{"Item":{"author":{"S":"Ada"},"title":{"S":"Sketch"},"year":{"N":"1842"}}}}]}'
aws dynamodb get-item --table-name Books --key '{"author":{"S":"Ada"},"title":{"S":"Notes"}}'
aws dynamodb query --table-name Books --key-condition-expression "author = :a" --expression-attribute-values '{":a":{"S":"Ada"}}' --query '{Count:Count,Titles:Items[].title.S}'
```

Ask for a key you never put with `get-item` and it prints nothing: a missing DynamoDB item is an empty reply, where a missing S3 key is an error. Ask for any other service, Lambda for one, and you get an error.

## For teachers

Nothing in this lab is marked automatically. **Ask for the replies** to a short session of the student's own: a bucket with an object put and got, a queue with a message sent, received and deleted, a table with an item put, got and queried, and the error for a key that is not there. Then one sentence on what MiniStack is not: it is an emulator, a practice copy, and not AWS. A copy is private to the student who started it, and a member of staff who teaches the module can open it, which is written to the access log the student can read.

## What does not work in a lab

This is three services of an emulator, not AWS. There is no account, no region to choose, no permission system to meet and no bill, and details differ from the real services: the account number in a queue's address is `000000000000`, message ids and times are not the real formats, and `--visibility-timeout 0` is read as the default 30 seconds. Lambda and the other services are switched off. The lab has no way out to the internet, so nothing can be downloaded into it.

## Checking the lab

`test/check.sh` starts the lab the way the platform's runner starts every service (all capabilities dropped except those a root service is given back, `no-new-privileges`, a process limit, a memory limit and no way out to the internet) and then checks from inside its network that only the three services are on, that a Lambda request is refused, that the commands above print what this page says, and that what was made survives the containers being removed and started again. It needs Docker and runs on every push.

```bash
test/check.sh
```

## Versions and licences

[MiniStack](https://github.com/ministackorg/ministack) is MIT licensed. The image is `ministackorg/ministack:1.4.8`.

## Licence

This work is licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). You may share it and adapt it for learning and teaching, if you credit Mitsuru Technologies Ltd, do not use it commercially, and share anything you make from it under the same licence. The full text is in the `LICENSE` file.

## About

Made by [Mitsuru Technologies](https://mitsurutech.co.uk) for the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning): Python, Java, Go, Node, SQL and Linux in the browser for schools and colleges, with container labs, web apps deployed from GitHub, and quizzes that mark themselves. Try code with no account in the [playground](https://mitsurutech.co.uk/playground).

More labs from the same place: [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-spark](https://github.com/mitsurutech/lab-spark), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) and [lab-sample](https://github.com/mitsurutech/lab-sample).
