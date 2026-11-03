# Docker Compose で AWS S3、SQS、DynamoDB を練習する：生徒向けクラウドコンピューティングのラボ

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml)

教室でそのまま使える **クラウドコンピューティングのラボ** です。学校や大学が、生徒ひとりひとりに専用のデータベース、コンテナ、ブラウザー上のターミナルを渡す [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning) のものです。生徒はそれぞれ専用の練習用クラウド、[MiniStack](https://github.com/ministackorg/ministack) を持ちます。**Amazon S3、SQS、DynamoDB** と同じ要求に答えるエミュレーターです。横のターミナルから本物の AWS コマンドラインを使って、**バケットを作ってオブジェクトを保存し、キューのメッセージを送って受け取って削除し、テーブルに項目を保存して読んで問い合わせます**。インストールは不要で、AWS アカウントを開く必要も、料金もかかりません。

ファイルは `docker-compose` の `compose.yaml` ひとつで、手元のマシンでもプラットフォームと同じように動きます。プラットフォームでは、どのコピーもインターネットに出られません。これは **エミュレーターで、AWS ではありません**。

## 中身

| サービス | イメージ | メモリ | 内容 |
| --- | --- | --- | --- |
| `cloud` | [`ministackorg/ministack:1.4.8`](https://hub.docker.com/r/ministackorg/ministack) | 256 MB | S3、SQS、DynamoDB だけを有効にした MiniStack |

大事な設定は `SERVICES: s3,sqs,dynamodb` です。MiniStack はこの3つに答え、ほかのサービスは `Unsupported service` で拒みます。**Lambda はわざと含めていません**。その関数は、生徒自身のコードをスタックのコンテナの中で root として実行してしまうからです。`aws lambda list-functions` はエラーで終わり、`test/check.sh` がそれを確かめます。状態は名前つきボリューム（`PERSIST_STATE`、`S3_PERSIST`）に保存されるので、ラボを停止して起動しなおしても、バケット、キュー、テーブルは残ります。スタックはパスワードを確かめないので、レッスンはコマンドラインに作り物のキーを渡します。イメージは MiniStack 自身のもので、MIT ライセンス、無変更で、バージョンを固定して（`latest` は使わず）動かします。下のコマンドを実行する間、ピークで約 75 MB を使い、割り当ては 256 MB です。

## プラットフォームで使う

種類 **ラボ** の課題を作り、**GitHub リポジトリ内** を選んで、`https://github.com/mitsurutech/lab-cloud` とブランチ `main` を指定します。compose ファイルの既定は `compose.yaml` です。変更したいときは先にフォークしてください。公開すると、生徒ひとりひとりのコピーは公開したコミットから始まります。先に試すには、[コンテナのページ](https://mitsurutech.co.uk/container) を開き、サンプルラボの **Cloud** を見つけて開始を押します。Git と SQL 以外のラボには無料アカウントが必要です。

ヘルプマニュアルには、[このラボのページ](https://mitsurutech.co.uk/help/lab-cloud) と [コンテナラボのガイド](https://mitsurutech.co.uk/help/labs) があります。compose ファイルに書けること、コピーが受け取るメモリ、先生が生徒のターミナルを見たり引き継いだりする方法がわかります。このラボは、[Learning Platform](https://mitsurutech.co.uk/learning) のクラウドコンピューティング実践モジュールに付属します。そのモジュールの課題は、取り込んだ答えを使う Python で、ラボは要りません。

学校のアカウントがまだですか。[最初の1年は無料](https://mitsurutech.co.uk/pricing)で、50人までです。[登録](https://mitsurutech.co.uk/signup)にはメールアドレスだけが必要です。

## 手元のマシンで動かす

Docker と Compose プラグインが必要です。`local.yaml` はポートを `127.0.0.1` だけに公開します。

```bash
docker compose -f compose.yaml -f local.yaml up
```

そのあと、ご自分の AWS コマンドラインを `AWS_ENDPOINT_URL=http://localhost:4566`、下の作り物のキーとリージョン、同じコマンドでそこに向けます。`Ctrl-C` で止め、`docker compose -f compose.yaml -f local.yaml down -v` で削除します。

## 進め方

ラボのターミナルで行います。ターミナルはスタックにサービス名 `cloud` でつながります。各手順は、次のように表示します。`make_bucket: lab-bucket`、読み戻した `hello cloud`、`NoSuchKey` の名前が入ったエラー。`Body` のあるメッセージと、そのあとの削除。`"ACTIVE"`、値が型に包まれた項目（`S` は文字、`N` は数）、そして `Count` が `2`。

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

保存していないキーを `get-item` でたずねると何も表示されません。ない DynamoDB の項目は空の返事で、ない S3 のキーはエラーです。ほかのサービス、たとえば Lambda をたずねると、エラーが返ります。

## 先生へ

このラボに自動採点はありません。**返事を提出させてください**。生徒自身の短いセッションの、オブジェクトを送って読んだバケット、メッセージを送って受け取って削除したキュー、項目を保存して読んで問い合わせたテーブル、ないキーのエラーです。そのあとに、MiniStack が何ではないかを一文で書かせます。AWS ではなく、エミュレーター、つまり練習用の複製です。コピーは起動した生徒だけのもので、モジュールを教える職員は開けます。それは生徒が読めるアクセスログに記録されます。

## ラボでは動かないこと

これはエミュレーターの3つのサービスで、AWS ではありません。アカウントも、選ぶリージョンも、権限の仕組みも、請求もなく、本物のサービスとは細部が違います。キューのアドレスのアカウント番号は `000000000000` で、メッセージ ID や時刻は本物の形式ではなく、`--visibility-timeout 0` は既定の30秒として読まれます。Lambda とほかのサービスは止めてあります。ラボはインターネットに出られないので、何もダウンロードできません。

## ラボを確かめる

`test/check.sh` は、プラットフォームのランナーが各サービスを起動するのと同じ方法でラボを起動し（root のサービスに返すもの以外の権限をすべて外し、`no-new-privileges`、プロセス数の上限、メモリの上限、インターネットへの出口なし）、そのネットワークの中から、3つのサービスだけが動いていること、Lambda への要求が拒まれること、上のコマンドがこのページのとおりに表示すること、作ったものがコンテナの削除と再起動のあとも残ることを確かめます。Docker が必要で、push のたびに動きます。

```bash
test/check.sh
```

## バージョンとライセンス

[MiniStack](https://github.com/ministackorg/ministack) は MIT ライセンスです。イメージは `ministackorg/ministack:1.4.8` です。

## ライセンス

この作品は [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) のもとで公開されています。学ぶため、教えるために共有・改変できます。ただし、Mitsuru Technologies Ltd のクレジットを示し、商用には使わず、作ったものは同じライセンスで共有してください。全文は `LICENSE` ファイルにあります。

## このリポジトリについて

[Mitsuru Technologies](https://mitsurutech.co.uk) が [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning) のために作りました。学校や大学向けに、Python、Java、Go、Node、SQL、Linux をブラウザーで学べ、コンテナラボ、GitHub から展開する Web アプリ、自動採点のクイズがあります。アカウントなしで [プレイグラウンド](https://mitsurutech.co.uk/playground) でコードを試せます。

同じところの他のラボ： [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-spark](https://github.com/mitsurutech/lab-spark), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea)、[lab-sample](https://github.com/mitsurutech/lab-sample)。
