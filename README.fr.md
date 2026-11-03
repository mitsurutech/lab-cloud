# Pratiquer AWS S3, SQS et DynamoDB avec Docker Compose : un lab de cloud computing pour élèves

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml)

Un **lab de cloud computing** prêt à l’emploi pour la classe, de la [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning), où écoles et établissements donnent à chaque élève ses propres bases de données, conteneurs et terminal dans le navigateur. Chaque élève reçoit son propre cloud d’entraînement, [MiniStack](https://github.com/ministackorg/ministack), un émulateur qui répond aux mêmes requêtes qu’**Amazon S3, SQS et DynamoDB**. Depuis le terminal à côté, il utilise la vraie ligne de commande AWS pour **créer un bucket et y ranger un objet, envoyer, recevoir et supprimer un message d’une file, et ajouter, lire et interroger des éléments dans une table**, sans rien installer ni compte AWS à ouvrir ou à payer.

C’est un seul fichier `docker-compose`, `compose.yaml`, qui fonctionne de la même façon sur votre machine que sur la plateforme, où chaque copie n’a aucun accès à internet. C’est un **émulateur, pas AWS**.

## Ce qu’il contient

| Service | Image | Mémoire | Ce que c’est |
| --- | --- | --- | --- |
| `cloud` | [`ministackorg/ministack:1.4.8`](https://hub.docker.com/r/ministackorg/ministack) | 256 MB | MiniStack avec seulement S3, SQS et DynamoDB activés |

Le réglage qui compte est `SERVICES: s3,sqs,dynamodb`. MiniStack répond alors à ces trois services et refuse tous les autres avec `Unsupported service`. **Lambda n’en fait volontairement pas partie** : ses fonctions exécuteraient le code de l’élève dans le conteneur de la pile, en root. `aws lambda list-functions` se termine par une erreur, et `test/check.sh` le vérifie. L’état est gardé dans un volume nommé (`PERSIST_STATE`, `S3_PERSIST`) : buckets, files et tables sont toujours là après l’arrêt puis le redémarrage du lab. La pile ne vérifie aucun mot de passe, la leçon donne donc une clé inventée à la ligne de commande. L’image est celle de MiniStack, sous licence MIT, lancée sans modification et figée à une version (jamais `latest`). Elle a utilisé environ 75 Mo au plus pendant les commandes ci-dessous, et dispose de 256 Mo.

## L’utiliser sur la plateforme

Créez une tâche de type **Lab**, choisissez **Dans un dépôt GitHub** et indiquez `https://github.com/mitsurutech/lab-cloud` avec la branche `main` ; le fichier compose par défaut est `compose.yaml`. Faites-en d’abord un fork pour le modifier. Publiez, et la copie de chaque élève part du commit publié. Pour l’essayer d’abord, ouvrez la [page des conteneurs](https://mitsurutech.co.uk/container), trouvez **Cloud** dans les laboratoires d’exemple et appuyez sur Démarrer. Un compte gratuit est nécessaire pour tous les labs sauf Git et SQL.

Le manuel d’aide a une [page pour ce lab](https://mitsurutech.co.uk/help/lab-cloud) et un [guide des labs de conteneurs](https://mitsurutech.co.uk/help/labs) : ce qu’un fichier compose peut dire, combien de mémoire reçoit une copie, et comment les enseignants regardent et reprennent le terminal d’un élève. Le lab accompagne le module de pratique du cloud de la [Learning Platform](https://mitsurutech.co.uk/learning), dont les travaux sont du Python sur des réponses capturées et n’ont pas besoin de lab.

Pas encore de compte d’établissement ? [Votre première année est gratuite](https://mitsurutech.co.uk/pricing) jusqu’à 50 élèves, et l’[inscription](https://mitsurutech.co.uk/signup) demande une adresse e-mail.

## Le lancer sur votre machine

Il faut Docker avec le plugin Compose. `local.yaml` publie le port sur `127.0.0.1` seulement.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Pointez ensuite votre propre ligne de commande AWS dessus avec `AWS_ENDPOINT_URL=http://localhost:4566`, la clé inventée et la région ci-dessous, et les mêmes commandes. Arrêtez-le avec `Ctrl-C` et supprimez-le avec `docker compose -f compose.yaml -f local.yaml down -v`.

## Pas à pas

Dans le terminal du lab, qui atteint la pile par le nom de son service, `cloud`. Chaque étape affiche ce qui est attendu : `make_bucket: lab-bucket`, puis `hello cloud` relu, puis une erreur qui nomme `NoSuchKey` ; un message avec son `Body`, qui est ensuite supprimé ; `"ACTIVE"`, puis un élément dont les valeurs sont enveloppées dans leur type (`S` texte, `N` nombre), puis `Count` `2`.

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

Demandez avec `get-item` une clé jamais ajoutée : rien ne s’affiche, un élément DynamoDB absent étant une réponse vide là où une clé S3 absente est une erreur. Demandez n’importe quel autre service, Lambda par exemple, et vous obtenez une erreur.

## Pour les enseignants

Rien dans ce lab ne se corrige tout seul. **Demandez les réponses** d’une courte session de l’élève : un bucket avec un objet envoyé et lu, une file avec un message envoyé, reçu et supprimé, une table avec un élément ajouté, lu et interrogé, et l’erreur pour une clé absente. Puis une phrase sur ce que MiniStack n’est pas : un émulateur, une copie d’entraînement, et non AWS. Une copie est privée à l’élève qui l’a lancée, et un membre du personnel qui enseigne le module peut l’ouvrir, ce qui est consigné dans le journal d’accès que l’élève peut lire.

## Ce qui ne marche pas dans un lab

Ce sont trois services d’un émulateur, pas AWS. Il n’y a ni compte, ni région à choisir, ni système de permissions à rencontrer, ni facture, et des détails diffèrent des vrais services : le numéro de compte dans l’adresse d’une file est `000000000000`, les identifiants de message et les heures n’ont pas les vrais formats, et `--visibility-timeout 0` est lu comme les 30 secondes par défaut. Lambda et les autres services sont désactivés. Le lab n’a aucun accès à internet, rien ne peut donc y être téléchargé.

## Vérifier le lab

`test/check.sh` lance le lab comme le fait le runner de la plateforme pour chaque service (toutes les capacités retirées sauf celles rendues à un service root, `no-new-privileges`, une limite de processus, une limite de mémoire et aucun accès à internet), puis vérifie depuis son réseau que seuls les trois services sont actifs, qu’une requête Lambda est refusée, que les commandes ci-dessus affichent ce que dit cette page, et que ce qui a été créé survit à la suppression puis au redémarrage des conteneurs. Il faut Docker, et il tourne à chaque push.

```bash
test/check.sh
```

## Versions et licences

[MiniStack](https://github.com/ministackorg/ministack) est sous licence MIT. L’image est `ministackorg/ministack:1.4.8`.

## Licence

Cette œuvre est sous licence [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Vous pouvez la partager et l’adapter pour apprendre et enseigner, si vous citez Mitsuru Technologies Ltd, ne l’utilisez pas commercialement et partagez ce que vous en faites sous la même licence. Le texte complet est dans le fichier `LICENSE`.

## À propos

Réalisé par [Mitsuru Technologies](https://mitsurutech.co.uk) pour la [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning) : Python, Java, Go, Node, SQL et Linux dans le navigateur pour écoles et établissements, avec des labs de conteneurs, des applications web déployées depuis GitHub et des quiz qui se corrigent seuls. Essayez du code sans compte dans le [playground](https://mitsurutech.co.uk/playground).

D’autres labs du même endroit : [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-spark](https://github.com/mitsurutech/lab-spark), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) et [lab-sample](https://github.com/mitsurutech/lab-sample).
