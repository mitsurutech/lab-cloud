# AWS S3, SQS und DynamoDB üben mit Docker Compose: ein Cloud-Computing-Lab für Lernende

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml)

Ein fertiges **Cloud-Computing-Lab** für den Unterricht, von der [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning), auf der Schulen und Hochschulen jeder lernenden Person eigene Datenbanken, Container und ein Terminal im Browser geben. Jede Person bekommt ihre eigene Übungs-Cloud, [MiniStack](https://github.com/ministackorg/ministack), einen Emulator, der dieselben Anfragen beantwortet wie **Amazon S3, SQS und DynamoDB**. Vom Terminal daneben benutzt sie die echte AWS-Befehlszeile, um **einen Bucket anzulegen und ein Objekt zu speichern, eine Nachricht einer Warteschlange zu senden, zu empfangen und zu löschen und Einträge in einer Tabelle zu speichern, zu lesen und abzufragen**, ohne etwas zu installieren und ohne ein AWS-Konto zu eröffnen oder zu bezahlen.

Es ist eine einzige `docker-compose`-Datei, `compose.yaml`, und sie läuft auf deinem Rechner genauso wie auf der Plattform, wo jede Kopie keinen Weg ins Internet hat. Es ist ein **Emulator, nicht AWS**.

## Was drin ist

| Dienst | Image | Speicher | Was es ist |
| --- | --- | --- | --- |
| `cloud` | [`ministackorg/ministack:1.4.8`](https://hub.docker.com/r/ministackorg/ministack) | 256 MB | MiniStack mit nur S3, SQS und DynamoDB eingeschaltet |

Die Einstellung, auf die es ankommt, ist `SERVICES: s3,sqs,dynamodb`. MiniStack beantwortet dann diese drei Dienste und lehnt jeden anderen mit `Unsupported service` ab. **Lambda gehört absichtlich nicht dazu**: Seine Funktionen würden den Code der Lernenden im Container des Stacks ausführen, als root. `aws lambda list-functions` endet mit einem Fehler, und `test/check.sh` prüft das. Der Zustand liegt in einem benannten Volume (`PERSIST_STATE`, `S3_PERSIST`), Buckets, Warteschlangen und Tabellen sind also nach dem Beenden und Starten des Labs noch da. Der Stack prüft kein Passwort, deshalb gibt die Lektion der Befehlszeile einen ausgedachten Schlüssel. Das Image ist das von MiniStack selbst, unter MIT-Lizenz, unverändert und auf eine Version festgelegt (nie `latest`). Es brauchte höchstens etwa 75 MB, während die Befehle unten liefen, und hat 256 MB.

## Auf der Plattform benutzen

Lege eine Aufgabe vom Typ **Lab** an, wähle **In einem GitHub-Repository** und gib `https://github.com/mitsurutech/lab-cloud` mit dem Branch `main` an; die Compose-Datei ist standardmäßig `compose.yaml`. Forke das Repository zuerst, um sie zu ändern. Veröffentliche, und die Kopie jeder lernenden Person startet vom veröffentlichten Commit. Zum Ausprobieren öffne die [Container-Seite](https://mitsurutech.co.uk/container), finde **Cloud** bei den Beispiel-Labs und drücke Start. Für jedes Lab außer Git und SQL ist ein kostenloses Konto nötig.

Das Hilfehandbuch hat eine [Seite zu diesem Lab](https://mitsurutech.co.uk/help/lab-cloud) und eine [Anleitung zu Container-Labs](https://mitsurutech.co.uk/help/labs): was eine Compose-Datei sagen darf, wie viel Speicher eine Kopie bekommt und wie Lehrkräfte das Terminal einer lernenden Person ansehen und übernehmen. Das Lab gehört zum Modul Praxis des Cloud Computing der [Learning Platform](https://mitsurutech.co.uk/learning), dessen Aufgaben Python über aufgezeichnete Antworten sind und kein Lab brauchen.

Noch kein Konto für Ihre Einrichtung? [Das erste Jahr ist kostenlos](https://mitsurutech.co.uk/pricing) für bis zu 50 Lernende, und die [Anmeldung](https://mitsurutech.co.uk/signup) braucht nur eine E-Mail-Adresse.

## Auf dem eigenen Rechner ausführen

Du brauchst Docker mit dem Compose-Plugin. `local.yaml` veröffentlicht den Port nur auf `127.0.0.1`.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Richte dann deine eigene AWS-Befehlszeile mit `AWS_ENDPOINT_URL=http://localhost:4566`, dem ausgedachten Schlüssel und der Region unten und denselben Befehlen darauf. Beende es mit `Ctrl-C` und entferne es mit `docker compose -f compose.yaml -f local.yaml down -v`.

## Schritt für Schritt

Im Terminal des Labs, das den Stack unter dem Namen seines Dienstes erreicht, `cloud`. Jeder Schritt gibt aus, was erwartet wird: `make_bucket: lab-bucket`, dann `hello cloud` zurückgelesen, dann ein Fehler mit `NoSuchKey`; eine Nachricht mit ihrem `Body`, die danach gelöscht wird; `"ACTIVE"`, dann ein Eintrag mit in Typen eingepackten Werten (`S` Text, `N` Zahl), dann `Count` `2`.

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

Frag mit `get-item` einen Schlüssel ab, den du nie gespeichert hast, und es wird nichts ausgegeben: Ein fehlender DynamoDB-Eintrag ist eine leere Antwort, ein fehlender S3-Schlüssel dagegen ein Fehler. Frag einen anderen Dienst an, etwa Lambda, und du bekommst einen Fehler.

## Für Lehrkräfte

Nichts in diesem Lab bewertet sich selbst. **Lassen Sie sich die Antworten** einer kurzen eigenen Sitzung abgeben: ein Bucket mit einem hochgeladenen und gelesenen Objekt, eine Warteschlange mit einer gesendeten, empfangenen und gelöschten Nachricht, eine Tabelle mit einem gespeicherten, gelesenen und abgefragten Eintrag und der Fehler für einen fehlenden Schlüssel. Dazu ein Satz darüber, was MiniStack nicht ist: ein Emulator, eine Übungskopie, und nicht AWS. Eine Kopie gehört nur der Person, die sie gestartet hat, und eine Lehrkraft des Moduls kann sie öffnen, was im Zugriffsprotokoll steht, das die lernende Person lesen kann.

## Was in einem Lab nicht funktioniert

Das sind drei Dienste eines Emulators, nicht AWS. Es gibt kein Konto, keine Region zur Auswahl, kein Berechtigungssystem und keine Rechnung, und Einzelheiten unterscheiden sich von den echten Diensten: Die Kontonummer in der Adresse einer Warteschlange ist `000000000000`, Nachrichten-IDs und Uhrzeiten haben nicht die echten Formate, und `--visibility-timeout 0` wird als die Standardvorgabe von 30 Sekunden gelesen. Lambda und die anderen Dienste sind abgeschaltet. Das Lab hat keinen Weg ins Internet, es kann also nichts hineingeladen werden.

## Das Lab prüfen

`test/check.sh` startet das Lab so, wie der Runner der Plattform jeden Dienst startet (alle Capabilities entfernt außer denen, die ein Root-Dienst zurückbekommt, `no-new-privileges`, ein Prozesslimit, ein Speicherlimit und kein Weg ins Internet), und prüft dann aus seinem Netz, dass nur die drei Dienste laufen, dass eine Lambda-Anfrage abgelehnt wird, dass die Befehle oben ausgeben, was diese Seite sagt, und dass das Angelegte das Entfernen und erneute Starten der Container übersteht. Es braucht Docker und läuft bei jedem Push.

```bash
test/check.sh
```

## Versionen und Lizenzen

[MiniStack](https://github.com/ministackorg/ministack) steht unter der MIT-Lizenz. Das Image ist `ministackorg/ministack:1.4.8`.

## Lizenz

Dieses Werk steht unter der Lizenz [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Du darfst es zum Lernen und Lehren teilen und anpassen, wenn du Mitsuru Technologies Ltd nennst, es nicht kommerziell nutzt und Abgeleitetes unter derselben Lizenz teilst. Der vollständige Text steht in der Datei `LICENSE`.

## Über

Gemacht von [Mitsuru Technologies](https://mitsurutech.co.uk) für die [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning): Python, Java, Go, Node, SQL und Linux im Browser für Schulen und Hochschulen, mit Container-Labs, aus GitHub bereitgestellten Web-Apps und Quizzen, die sich selbst bewerten. Probiere Code ohne Konto im [Playground](https://mitsurutech.co.uk/playground).

Weitere Labs vom selben Ort: [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-spark](https://github.com/mitsurutech/lab-spark), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) und [lab-sample](https://github.com/mitsurutech/lab-sample).
