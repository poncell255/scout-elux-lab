# Site de provas: Flask + waitress + libfprint 1.94 (a mesma do Ubuntu 22.04 usada no pacote populos_digital do eLux)
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
      python3-flask python3-waitress libfprint-2-2 libfprint-2-dev libglib2.0-dev gcc libc6-dev pkg-config ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*
COPY cadastro/ /src/
RUN gcc -O2 -o /usr/local/bin/cadastrar-digital /src/cadastrar-digital.c $(pkg-config --cflags --libs libfprint-2) \
 && gcc -O2 -o /usr/local/bin/ler-digital /src/ler-digital.c $(pkg-config --cflags --libs libfprint-2)
ENV TZ=America/Sao_Paulo PYTHONUNBUFFERED=1
WORKDIR /app
EXPOSE 3100
CMD ["python3", "/app/app.py"]
