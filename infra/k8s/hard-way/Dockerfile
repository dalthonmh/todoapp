# Ubuntu 24 LTS
FROM ubuntu:noble

# Evitar prompts interactivos durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Actualizar paquetes e instalar herramientas necesarias
RUN apt-get update && apt-get install -y \
    curl \
    vim \
    nano \
    certbot \
    ca-certificates \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod 755 kubectl \
    && mv kubectl /usr/local/bin/ \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Restablecer la variable de entorno
ENV DEBIAN_FRONTEND=

# Mantener el contenedor ejecutándose
CMD ["tail", "-f", "/dev/null"]