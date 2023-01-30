Metodología de trabajo para Magento 2 sobre una estructura de contenedores Docker con Docker Compose

# Capas del stack tecnológico

Todos los entornos constan de las mismas capas: desde el entorno de producción hasta los entornos locales de desarrollo (en este último caso, siempre que se utilice la plantilla docker compose que proveemos).

El stack se compone de las siguientes capas:

- HAProxy: controlador de ingreso y terminador TLS
- Varnish: acelerador web / proxy caché inverso
- Proxy Webpack (sólo en desarrollo React)
- Nginx: servidor web
- PHP-FPM: servidor de aplicación
- MariaDB: base de datos
- Redis (Almacén clave-valor), tres contenedores: para sesiones, aplicación y página completa (FPC) (en caso de no usar Varnish)
- Elasticsearch: motor especializado de búsqueda requerido por defecto por Magento desde la versión 2.4
- RabbitMQ: cola de mensajes en la que apoya Magneto para la ejeceución de tareas asíncronas
- Mailhog: servicio para la recepción de correo en entornos de desarrollo

Trabajamos sobre los siguientes fundamentos:

### Dominio y TLD

El entorno de desarrollo debe servirse en un dominio propio (evitamos el nombre `localhost`) y en los puertos HTTP/S estándar (80 y 443).

Preferimos mantener las dependencias al mínimo evitando el uso de un servicio DNS para desarrollo. Utilizaremos uno de los TLD reservados para pruebas (IETF RFC2606): `.test`, `.example`, `.invalid`, `.localhost`.

Escogemos el TLD localhost porque ya implica una resolución a la IP de loopback y evita mapeos innecesarios.

### Seguridad: HTTPS

Creemos que el stack de desarrollo debe ser un modelo a menor escala del de producción de forma que una petición atraviese las mismas etapas. Por otro lado nos gusta diferenciarnos implementando conexiones seguras también para los entornos de desarrollo.

Un sencillo contenedor propio (cert-issuer) se encarga de crear, **en caso de no existir con anterioridad**, un certificado de CA para el entorno de desarrollo. Este certificado se almacenará en la máquina host en el directorio indicado en la variable de entorno `CADIR`, por defecto en `~/.local/etc/ca-certificates`. Esta CA se usará tambien para el resto de proyectos, por lo que sólo es necesario hacer que bien el sistema o bien el navegador usado para el desarrollo confíen en 

    ~/.local/etc/ca-certificates/local-ca.crt

Los certificados para la capa de ingreso se crearán y montarán automáticamente.

### Seguridad: claves

Las claves entre sistemas son seguras y autogeneradas. Un ser humano no debería ver ni ser el responsable de pensar ninguna clave compartida entre servicios que no sean su login personal.

Para ello utilizamos un sencillo script propio (shhh) que crea claves aleatorias y las almacena en ficheros que luego se montarán en los contenedores. Por ejemplo:

    /shhh/mysql:root.shhh
    /shhh/mysql:user.shhh

Durante el arranque de MariaDB se creará un usuario `app`, y se establecerán las claves generadas por `shhh` para `root` y `app`.

También se habrá creado un fichero `my.cnf` en la *home* del usuario que ejecuta el contenedor `db` para poder acceder a mysql sin necesidad de clave.

Creemos que mantener nombres genéricos (app) dentro de una aplicación evita problemas, en lugar de utilizar valores como pueda ser el nombre del proyecto. Si fuese necesaria otra base de datos en el mismo contenedor (o mismos), se utilizaría otro nombre genérico (por ejemplo, `wordpress`) o un servicio diferente en su propio contenedor y con el usuario `app`.

### Contenedores

Preferimos utilizar imágenes oficiales siempre que sea posible, montando los ficheros de configuración necesarios. Esto evita mantener imágenes propias tras actualizaciones o nuevas versiones de las oficiales.

Una excepción son los contenedores de PHP (PHP-FPM y CLI). Las imágenes oficiales son demasiado elementales y es necesario instalar y configurar diversos módulos para producción y desarrollo en un proceso que realmente no es sencillo. Por ello utilizamos imágenes propias y las publicamos en Docker Hub <https://hub.docker.com/r/admibox/php>. Los Dockerfile y el código para generarlos automáticamente para todas las versiones de PHP se encuentra en GitHub: <https://github.com/admibox/php-docker-images>.

Hemos preparado el contenedor CLI con todas las herramientas necesarias para que el trabajo sea una experiencia agradable.

### Permisos

El servicio de sistema *docker* se ejecuta con permisos de root. Por defecto, los contenedores ejecutan su código como usuario root (interno al contenedor, pero al ser el UID 0, los ficheros que crea tienen como propietario root).

El fichero docker-compose.yaml está preparado para ejecutar los contenedores susceptibles de crear ficheros (PHP-CLI y PHP-FPM) como el usuario y grupo indicados en las variables de entorno HOST_UID y HOST_GID (por defecto, 0).

Esto evita muchos dolores de cabeza y operaciones con `sudo` durante la ejecución en desarrollo.

## Preparación del entorno

Suponemos un entorno de ejecución Linux (preferible) o MacOS. Para Windows no sería complicado hacer las adaptaciones oportunas. El mayor rendimiento, con un sobrecarga casi desprecible, se obtiene en Linux. En MacOS existe una capa adicional para el acceso al almacenamiento, lo que en una aplicación como Magento, con una gran cantidad de ficheros de código, la merma de rendimiento es muy severa. No hay una gran sobrecarga en cuanto a uso de CPU (en aplicaciones con un árbol de código reducido, como *WordPress*, apenas hay pérdida de rendimiento aunque hagan uso intensivo de la CPU), sino del acceso al almacenamiento.

Las referencias a ~/.local/run no las vamos a utilizar ahora. Se trata de que, además de escuchar en los puertos estándar 80 y 443, los controladores de ingreso escuchan en ficheros *socket* unix. Internamente utilizamos por encima un proxy TCP muy sencillo con capacidad SNI que redirige las peticiones al *socket* correspondiente según el dominio. Esto nos permite trabajar con múltiples proyectos a la vez sin preocuparnos por colisiones o conflictos entre puertos.

    mkdir -p ~/.local/etc/ca-certificates ~/.local/run

Opcional: crear las variables de entorno necesarias para definir el usuario y grupo de ejecución de los servicios y el directorio donde se almacenarán los ficheros *socket*.

Si se usa `bash`:

    cat <<'EOT' >> ~/.bashrc
    export HOST_UID=${UID}
    export HOST_GID=${GID}
    export INGRESS_RUN_DIRECTORY=$HOME/.local/run
    EOT

    . ~/.bashrc

Si se usa `zsh`:

    cat <<'EOT' >> ~/.zshrc
    export HOST_UID=${UID}
    export HOST_GID=${GID}
    export INGRESS_RUN_DIRECTORY=$HOME/.local/run
    EOT

    . ~/.zshrc

Nosotros mantenemos separados los directorios de proyecto, gestionados con git, de la configuración de contenedores con la que servimos el proyecto en desarrollo. Esto es totalmente adaptable al entorno de cada cual, pero partiremos de la siguiente estructura:

    ~/dev/foostore.com

Directorio que contiene el repositorio de código del proyecto. Es el directorio raíz de Magento.

    ~/docker/foostore.com

Directorio que contiene el fichero `docker-compose.yaml` y el directorio `etc` de configuraciones (internamente también lo gestionamos con git).

La forma de relacionar la estructura de contenedores con el código fuente es mediante un fichero en entorno `.env`:

    cat <<'EOT' >> ~/docker/foostore.com/.env
    COMPOSE_PROJECT_NAME=foostore
    PRO_PRJ=foostore
    PRO_ENV=devel
    ROOT=~/dev/foostore.com
    DOMAIN=foostore.localhost
    INGRESS_RUN_DIRECTORY=~/.local/run/foostore.com
    SHARED=~/dev/shared
    EOT

`INGRESS_RUN_DIRECTORY` y `SHARED` no los vamos a utilizar por el momento.

Los contenedores PHP-CLI y PHP-FPM montan el fichero indicado en la variable de entorno `AUTH_JSON` (por defecto ~/auth.json) en la *home* de composer con el nomrbe `auth.json`. Esto evita introducir manualmente la clave de Magento. Para trabajar con más repositorios o gestionar `auth.json` por proyecto, puede usarse la variable `AUTH_JSON` en `.env` para adaptarla a las necesidades.

    # Reemplazar por las credenciales propias de acceso al repositorio de Magento

    cat <<'EOT' >> ~/auth.json
    {
        "http-basic": {
            "repo.magento.com": {
                "username": "xxxxxxxxx9edbcd1159d217xxxxxxxxx",
                "password": "xxxxxxxxxdfb30b49630fc4xxxxxxxxx"
            }
        }
    }
    EOT

Con esta estructura montada podemos levantar los contenedores:

    cd ~/docker/foostore.com && docker compose up -d

Tras unos instantes podemos comproabar que todos están levantados y funcionando

    docker ps

### Acceso a los servicios de los contenedores

Falta una parte de extrema importancia: la base de datos.

Pero antes necesitamos conocer de qué forma vamos a interactuar con los contenedores. Y lo haremos principalmente mediante invocaciones al comando `docker compose` desde el directorio `~/docker/foostore.com`.

Hemos preferido prescindir de comandos auxiliares. Cada cual puede definir los alias o ejecutables que considere oportunos.

#### Shell PHP

Acceso a una shell *zsh* desde la que invocar el intérprete CLI de PHP. Incluye un conjunto exhaustivo de herramientas, entre las que se encuentra el cliente `mysql`.

    docker compose run --rm php-cli

NOTA: el contenedor incluye las versiones 1 y 2 de *composer*. Por defecto, el comando `composer` es la versión 2. Magento requiere la versión 1, que se invoca mediante `composer1`.

#### MariaDB / MySQL

Acceso con el usuario `app` a la base de datos `app` (el acceso más común):

    docker compose exec db mysql app

Acceso con el usuario `root` a la base de datos `app` (siempre evitamos mostrar o teclear las claves):

    docker compose exec db mysql -uroot -p$(docker compose exec db cat /shhh/mysql:root.shhh) app

Dump de la base de datos, con marca de tiempo, al directorio `./dump`:

    mkdir -p dump && docker compose exec db mysqldump app | gzip > dump/app-$(date +%Y%m%d.%H%M%S).sql.gz

Importar una base de datos desde un fichero *.sql*, comprimido o no:

    zcat -f dump/app-xxxxxxxx.xxxxxx.sql.gz | docker exec -i $(docker compose ps -q db) mysql app

NOTA: La ejecución es diferente (`docker exec` en lugar de `docker compose exec`) porque hay algún problema con la redirección de la entrada estándar hacia `docker compose`.

### Base de datos

Aquí nos encontramos con dos situaciones: estamos empezando un nuevo proyecto o ya tenemos una base de datos que queremos trasladar al nuevo entorno.

Si estamos instalando Magento desde cero, el contenedor `PHP-CLI` ya está preparado con las variables de entorno necesarias para que la instalación desde línea de comandos funcione en una sola línea.

    docker compose run --rm php-cli

Y una vez dentro:

    php -d memory_limit=-1 bin/magento setup:install --base-url="https://$DOMAIN/" \
    --db-host=db --db-name=app \
    --db-user=app --db-password="$(cat /shhh/mysql:user.shhh)" \
    --admin-firstname=Magento --admin-lastname=Admin --admin-email=${ADMIN_EMAIL:-dev@admibox.com} \
    --admin-user=${ADMIN_USER:-myadmin} --admin-password=${ADMIN_PASSWORD:-myadmin123} --language=${LANGUAGE:-en_US} \
    --currency=${CURRENCY:-USD} --timezone=${TIMEZONE:-Europe/Madrid} --cleanup-database \
    --session-save=db --use-rewrites=1

Si estamos importando una base de datos existente, simplemente introducimos el fichero *dump* por la entrada estándar del cliente *mysql*:

    zcat -f /path/to/dump.sql.gz | docker exec -i $(docker compose ps -q db) mysql app

Y conviene recordar que suele ser necesario actualizar las variables de configuración de la tabla `core_config_data` para apuntar al nuevo dominio, si fuese necesario:

    docker compose exec db mysql app

Y una vez dentro:

    SELECT * FROM core_config_data WHERE path LIKE 'web/unsecure/%' OR path LIKE 'web/secure/%' OR path LIKE 'web/cookie/cookie_domain';

Y hacer los `UPDATE` necesarios. O bien utilizar nuestro módulo Ungento_Common, que permite sobreescribir estos valores desde el fichero `app/etc/env.php`.

#### Importante: clave de MySQL en `app/etc/env.php`

Preferimos no ver, ni copiar ni pegar ninguna clave y que sea el sistema quien se encargue de eso. Si fuese necesario (a veces lo es), podemos ver las claves de MySQL para `app` y `root` en los ficheros `/shhh/mysql:user.shhh` y `/shhh/mysql:root.shhh` de los contenedores `db`, `php-fpm` y `php-cli`:

docker compose exec db cat /shhh/mysql:user.shhh
docker compose exec db cat /shhh/mysql:root.shhh

Pero dado que la configuración de entorno de Magento se define en un fichero *.php*, podemos editar `app/etc/env.php` y hacer lo siguiente sin necesidad de mostrar la clave:

    'db' => [
        'table_prefix' => '',
        'connection' => [
            'default' => [
                'host' => 'db',
                'dbname' => 'app',
                'username' => 'app',
                'password' => file_get_contents('/shhh/mysql:user.shhh'),
                'active' => '1',
                'driver_options' => []
            ]
        ]
    ],

Aunque desgraciadamente Magento, tras ejecutar el comando `bin/magento setup:upgrade`, reescribe ese fichero y reemplaza el código por su contenido. Todo seguirá funcionando normalmente pero, a nuestro parecer, otra decisión desafortunada de Magento.
