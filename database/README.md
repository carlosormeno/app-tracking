# Base de datos

Scripts e infraestructura mínima para levantar PostgreSQL 16 + PostGIS 3.4 y aplicar el esquema inicial del proyecto.

## Requisitos
- Docker y Docker Compose instalados
- Puerto `5432` libre (ajustar en `docker-compose.yml` si ya está en uso)

## Levantar instancia local
```bash
cd database
# Primera vez (crea contenedor + aplica schema.sql)
docker compose up -d

# Verificar contenedor
docker compose ps
```

La primera inicialización ejecuta automáticamente `schema.sql` dentro del contenedor y deja creada la base `location_tracker` con las tablas `users` y `locations`, extensiones PostGIS y los índices críticos.

## Conectarse vía psql
```bash
# Abrir una consola dentro del contenedor
docker compose exec postgres psql -U locationapp -d location_tracker
```

## Migraciones (backend)
- El archivo `schema.sql` sirve como bootstrap automático del contenedor local.
- Para un flujo de migraciones controladas, puedes usar los SQL dentro de `migrations/` (formato Flyway), por ejemplo `migrations/V1__base_schema.sql`.
- Copia esos archivos a la carpeta de migraciones de tu backend (Flyway `classpath:db/migration`) o referencia el path desde tu herramienta de migraciones.
- Ejemplo de ejecución manual de la migración inicial desde el contenedor:
  ```bash
  docker compose exec postgres psql -U locationapp -d location_tracker -f /docker-entrypoint-initdb.d/00-schema.sql
  ```

## Aplicar cambios al esquema
Si editas `schema.sql` después de haber levantado la base, ejecuta el archivo manualmente:
```bash
docker compose exec postgres psql -U locationapp -d location_tracker -f /docker-entrypoint-initdb.d/00-schema.sql
```

> Cambia la variable `POSTGRES_PASSWORD` en `docker-compose.yml` antes de exponer la base fuera del entorno de desarrollo.

## Siguientes pasos sugeridos
- Añadir scripts de migración incremental (por ejemplo, con Flyway o Liquibase) cuando arranque el backend.
- Definir particionamiento mensual de `locations` si el volumen de datos lo requiere.
- Preparar seeds o fixtures de prueba si el frontend necesita datos de ejemplo.
