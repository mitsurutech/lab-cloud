# Practicar AWS S3, SQS y DynamoDB con Docker Compose: un laboratorio de computación en la nube para estudiantes

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-cloud/actions/workflows/check.yml)

Un **laboratorio de computación en la nube** listo para el aula, de la [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning), donde escuelas y centros dan a cada estudiante sus propias bases de datos, contenedores y terminal en el navegador. Cada estudiante recibe su propia nube de práctica, [MiniStack](https://github.com/ministackorg/ministack), un emulador que responde a las mismas peticiones que **Amazon S3, SQS y DynamoDB**. Desde el terminal de al lado usa la línea de comandos real de AWS para **crear un bucket y guardar un objeto, enviar, recibir y borrar un mensaje de una cola, y añadir, leer y consultar elementos de una tabla**, sin instalar nada y sin abrir ni pagar una cuenta de AWS.

Es un solo archivo `docker-compose`, `compose.yaml`, que funciona igual en tu máquina que en la plataforma, donde cada copia no tiene salida a internet. Es un **emulador, no AWS**.

## Qué contiene

| Servicio | Imagen | Memoria | Qué es |
| --- | --- | --- | --- |
| `cloud` | [`ministackorg/ministack:1.4.8`](https://hub.docker.com/r/ministackorg/ministack) | 256 MB | MiniStack con solo S3, SQS y DynamoDB activados |

El ajuste que importa es `SERVICES: s3,sqs,dynamodb`. MiniStack responde entonces a esos tres servicios y rechaza cualquier otro con `Unsupported service`. **Lambda no está entre ellos a propósito**: sus funciones ejecutarían el código del estudiante dentro del contenedor de la pila, como root. `aws lambda list-functions` acaba en un error, y `test/check.sh` lo comprueba. El estado se guarda en un volumen con nombre (`PERSIST_STATE`, `S3_PERSIST`), así que buckets, colas y tablas siguen ahí tras detener e iniciar el laboratorio. La pila no comprueba ninguna contraseña, así que la lección da a la línea de comandos una clave inventada. La imagen es la propia de MiniStack, con licencia MIT, ejecutada sin modificar y fijada a una versión (nunca `latest`). Usó unos 75 MB como máximo mientras se ejecutaban los comandos de abajo, y tiene 256 MB.

## Usarlo en la plataforma

Crea una tarea de tipo **Laboratorio**, elige **En un repositorio de GitHub** y da `https://github.com/mitsurutech/lab-cloud` con la rama `main`; el archivo compose por defecto es `compose.yaml`. Haz antes un fork para cambiarlo. Publica, y la copia de cada estudiante parte del commit publicado. Para probarlo antes, abre la [página de contenedores](https://mitsurutech.co.uk/container), busca **Cloud** en los laboratorios de ejemplo y pulsa Iniciar. Hace falta una cuenta gratuita para todos los laboratorios salvo los de Git y SQL.

El manual de ayuda tiene una [página para este laboratorio](https://mitsurutech.co.uk/help/lab-cloud) y una [guía de laboratorios de contenedores](https://mitsurutech.co.uk/help/labs): qué puede decir un archivo compose, cuánta memoria recibe una copia y cómo los docentes miran y toman el terminal de un estudiante. El laboratorio acompaña al módulo de práctica de computación en la nube de la [Learning Platform](https://mitsurutech.co.uk/learning), cuyas tareas son Python sobre respuestas capturadas y no necesitan laboratorio.

¿Aún no tienes cuenta de centro? [Tu primer año es gratis](https://mitsurutech.co.uk/pricing) hasta 50 estudiantes, y [registrarse](https://mitsurutech.co.uk/signup) pide un correo electrónico.

## Ejecutarlo en tu máquina

Necesitas Docker con el plugin Compose. `local.yaml` publica el puerto solo en `127.0.0.1`.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Después apunta tu propia línea de comandos de AWS a él con `AWS_ENDPOINT_URL=http://localhost:4566`, la clave inventada y la región de abajo, y los mismos comandos. Deténlo con `Ctrl-C` y elimínalo con `docker compose -f compose.yaml -f local.yaml down -v`.

## Paso a paso

En el terminal del laboratorio, que llega a la pila por el nombre de su servicio, `cloud`. Cada paso imprime lo esperado: `make_bucket: lab-bucket`, luego `hello cloud` leído de vuelta, luego un error que nombra `NoSuchKey`; un mensaje con su `Body` que después se borra; `"ACTIVE"`, luego un elemento con sus valores envueltos en tipos (`S` texto, `N` número), luego `Count` `2`.

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

Pide con `get-item` una clave que nunca añadiste y no imprime nada: un elemento de DynamoDB que falta es una respuesta vacía, donde una clave de S3 que falta es un error. Pide cualquier otro servicio, Lambda por ejemplo, y recibes un error.

## Para docentes

Nada en este laboratorio se corrige solo. **Pide las respuestas** de una sesión corta del estudiante: un bucket con un objeto enviado y leído, una cola con un mensaje enviado, recibido y borrado, una tabla con un elemento añadido, leído y consultado, y el error de una clave que no existe. Después una frase sobre lo que MiniStack no es: un emulador, una copia de práctica, y no AWS. Una copia es privada del estudiante que la inició, y un miembro del personal que imparte el módulo puede abrirla, lo que queda en el registro de acceso que el estudiante puede leer.

## Qué no funciona en un laboratorio

Son tres servicios de un emulador, no AWS. No hay cuenta, ni región que elegir, ni sistema de permisos que conocer, ni factura, y hay detalles que difieren de los servicios reales: el número de cuenta en la dirección de una cola es `000000000000`, los identificadores de mensaje y las horas no tienen los formatos reales, y `--visibility-timeout 0` se lee como los 30 segundos por defecto. Lambda y los demás servicios están desactivados. El laboratorio no tiene salida a internet, así que no se puede descargar nada en él.

## Comprobar el laboratorio

`test/check.sh` inicia el laboratorio como lo hace el runner de la plataforma con cada servicio (todas las capacidades quitadas salvo las que se devuelven a un servicio root, `no-new-privileges`, un límite de procesos, un límite de memoria y ninguna salida a internet) y luego comprueba desde su red que solo los tres servicios están activos, que una petición de Lambda se rechaza, que los comandos de arriba imprimen lo que dice esta página y que lo creado sobrevive a eliminar e iniciar de nuevo los contenedores. Necesita Docker y se ejecuta en cada push.

```bash
test/check.sh
```

## Versiones y licencias

[MiniStack](https://github.com/ministackorg/ministack) tiene licencia MIT. La imagen es `ministackorg/ministack:1.4.8`.

## Licencia

Esta obra tiene licencia [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Puedes compartirla y adaptarla para aprender y enseñar, si citas a Mitsuru Technologies Ltd, no la usas comercialmente y compartes lo que hagas con ella bajo la misma licencia. El texto completo está en el archivo `LICENSE`.

## Acerca de

Hecho por [Mitsuru Technologies](https://mitsurutech.co.uk) para la [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning): Python, Java, Go, Node, SQL y Linux en el navegador para escuelas y centros, con laboratorios de contenedores, aplicaciones web desplegadas desde GitHub y cuestionarios que se corrigen solos. Prueba código sin cuenta en el [playground](https://mitsurutech.co.uk/playground).

Más laboratorios del mismo sitio: [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-spark](https://github.com/mitsurutech/lab-spark), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) y [lab-sample](https://github.com/mitsurutech/lab-sample).
