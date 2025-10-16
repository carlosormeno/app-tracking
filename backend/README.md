# Location Backend

Spring Boot 3.5 (Java 21) backend for the location tracking platform. Provides REST APIs, connects to PostgreSQL/PostGIS, and exposes OpenAPI docs.

## Requisitos
- JDK 21 instalado
- Gradle 8.6+ (o usar el wrapper si se incorpora más adelante)
- Base de datos PostgreSQL/PostGIS corriendo (ver `../database`)

## Configuración
Las credenciales apuntan por defecto a la instancia local definida en `../database/docker-compose.yml`:
```
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/location_tracker
SPRING_DATASOURCE_USERNAME=locationapp
SPRING_DATASOURCE_PASSWORD=change_me
```

Configura variables de entorno o un archivo `.env` antes de arrancar, o modifica `src/main/resources/application.yml`.

## Ejecución
```bash
cd backend
gradle bootRun
```

Si se define un wrapper posteriormente:
```bash
./gradlew bootRun
```

## Endpoints útiles
- `GET /api/health/db` → Ejecuta `SELECT 1` contra la base para validar la conexión.
- `POST /api/users` → Crea/actualiza un usuario a partir de `firebaseUid` y email.
  ```json
  {
    "email": "test@example.com",
    "firebaseUid": "firebase-uid-123"
  }
  ```
- `GET /api/users/{firebaseUid}` → Obtiene los datos del usuario.
- `GET /api/locations/history?firebaseUid=UID&start=2025-10-15T00:00:00Z&end=2025-10-16T00:00:00Z`
  → Devuelve puntos ordenados cronológicamente y distancia total (km) en el periodo.
- `GET /api/locations/distance?firebaseUid=UID&date=2025-10-15`
  → Distancia recorrida en km para la fecha (UTC).
- `POST /api/locations` → Registra un punto de ubicación.
  ```json
  {
    "firebaseUid": "firebase-uid-123",
    "latitude": -12.0464,
    "longitude": -77.0428,
    "timestamp": "2025-10-15T12:00:00Z",
    "accuracy": 10.5,
    "batteryLevel": 80,
    "activityType": "walking"
  }
  ```
- `GET /swagger-ui` → Interfaz Swagger UI (via springdoc-openapi).
- `GET /v3/api-docs` → Documento OpenAPI en JSON.

## Próximos pasos
- Crear DTOs y servicios para operaciones de usuarios y ubicaciones.
- Añadir pruebas de integración que usen un contenedor PostgreSQL efímero (Testcontainers).
- Automatizar migraciones con Flyway reutilizando `database/migrations/V1__base_schema.sql`.
