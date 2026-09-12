# Zabbix CPU simulation

Este repositorio contiene una carga reproducible para probar un agente SRE frente a una alerta de CPU alta. Usa el stack Zabbix 7.4 que ya está ejecutándose y agrega un contenedor `zabbix-cpu-simulator` con Zabbix Agent 2 y `stress-ng`.

## Arranque

La red del stack existente se llama `despliegame-un-contenedor-de-zabbix-docker_default`.

```bash
docker compose -f docker-compose.cpu-simulation.yml up -d --build
docker compose -f docker-compose.cpu-simulation.yml ps
```

Provisión del host en Zabbix (credenciales por defecto `Admin` / `zabbix`):

```bash
docker run --rm --network host \
  -v "$PWD/scripts:/scripts:ro" alpine:3.20 sh -c \
  'apk add --no-cache bash curl jq >/dev/null && bash /scripts/provision-zabbix-cpu.sh'
```

Si el comando anterior no puede alcanzar `127.0.0.1` desde Docker Desktop, ejecuta el script desde Git Bash/WSL con `curl`, `jq` y Bash instalados:

```bash
bash scripts/provision-zabbix-cpu.sh
```

## Escenarios de prueba

`set-cpu-load.sh` recibe trabajadores, porcentaje y duración en segundos. Una duración `0` mantiene la carga hasta detenerla.

```bash
bash scripts/set-cpu-load.sh 2 95 180
bash scripts/set-cpu-load.sh 1 20 60
bash scripts/set-cpu-load.sh 0 0 1
```

La métrica principal es `system.cpu.util` del host `zabbix-cpu-simulator`. La plantilla estándar de Zabbix proporciona la métrica y sus triggers; el agente puede validar la alerta, consultar el estado y verificar la recuperación cuando la carga termina.

Para detener la simulación sin detener el agente:

```bash
docker exec zabbix-cpu-simulator pkill -f 'stress-ng --cpu' || true
```

La interfaz web queda en [http://127.0.0.1:8080](http://127.0.0.1:8080).
