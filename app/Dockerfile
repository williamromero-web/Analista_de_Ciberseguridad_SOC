# Cumplimiento: Tag pinneado obligatorio (no usamos :latest)
FROM node:20.14.0-alpine

# Parchear vulnerabilidades del sistema operativo base (Alpine)
RUN apk update && apk upgrade --no-cache

WORKDIR /usr/src/app

# Copiamos archivos de dependencias
COPY package*.json ./

# Instalamos las dependencias de la aplicación
RUN npm install --no-audit --no-fund

# REDUCCIÓN DE SUPERFICIE DE ATAQUE:
# Eliminamos npm del contenedor final para erradicar su dependencia de 'tar' vulnerable.
# El contenedor en producción no necesita instalar paquetes.
RUN rm -rf /usr/local/lib/node_modules/npm \
    && rm -f /usr/local/bin/npm \
    && rm -f /usr/local/bin/npx

# Copiamos el código fuente
COPY server.js .

EXPOSE 3000
CMD [ "node", "server.js" ]
