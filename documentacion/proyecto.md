# 📱 Proyecto: App de Tracking de Ubicación

## 📋 Índice

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Stack Tecnológico](#stack-tecnológico)
3. [Arquitectura](#arquitectura)
4. [Características Técnicas](#características-técnicas)
5. [Base de Datos](#base-de-datos)
6. [Plan de Desarrollo](#plan-de-desarrollo)
7. [Guía de Setup](#guía-de-setup)
8. [Código de Referencia](#código-de-referencia)
9. [Infraestructura](#infraestructura)
10. [Roadmap](#roadmap)

---

## 🎯 Resumen Ejecutivo

### Objetivo
Crear una aplicación móvil Android que capture la ubicación del usuario cada 5 minutos de forma no intrusiva, almacene el historial en una base de datos geoespacial, y permita visualizar por dónde estuvo en el tiempo. El soporte iOS queda planificado para una fase posterior junto con el análisis de rutas óptimas.

### Equipo
- **2 desarrolladores**
- **1 servidor propio**
- **Tiempo PoC:** 3 semanas

### Alcance MVP
- ✅ Tracking automático cada 5 minutos
- ✅ Visualización de rutas en mapa
- ✅ Historial por fechas
- ✅ Estadísticas básicas (distancia recorrida)
- ✅ Optimización de batería
- ✅ Login/Autenticación
- ✅ Distribución Android (Play Store/Test interno)

---

## 🛠️ Stack Tecnológico

### Frontend (Mobile)
```yaml
Plataforma: Flutter + Dart (MVP Android)
Motivo: Código compartido Android/iOS sin duplicar código; el MVP se enfoca en Android y deja preparado el port para la fase iOS.
Librerías principales:
  - geolocator: ^11.0.0           # Captura GPS
  - flutter_map: ^6.1.0            # Mapas OpenStreetMap
  - firebase_auth: ^4.15.3         # Autenticación
  - flutter_foreground_task: ^6.1.1 # Servicio background
  - battery_plus: ^5.0.2           # Monitoreo batería
  - http: ^1.1.2                   # API calls
```

### Backend
```yaml
Framework: Spring Boot 3.5.6 (Java 21)
Motivo: Ecosistema maduro, Hibernate Spatial estable
Dependencias:
  - Spring Web                     # REST API
  - Spring Data JPA                # ORM
  - PostgreSQL Driver              # Conexión DB
  - Hibernate Spatial              # PostGIS support
  - Lombok                         # Reducción de boilerplate
  - Spring Boot Validation         # Validaciones @Valid
  - Firebase Admin SDK 9.2.0       # Auth validation
  - Spring Security                # Seguridad
  - Springdoc OpenAPI              # Documentación Swagger
```

### Base de Datos
```yaml
Motor: PostgreSQL 16
Extensión: PostGIS 3.4
Motivo: Mejor opción para análisis geoespaciales y rutas óptimas
Características:
  - Queries geoespaciales nativas
  - Cálculo de distancias reales
  - Índices espaciales (GIST)
  - Soporte para algoritmos de rutas
```

### Autenticación
```yaml
Servicio: Firebase Authentication
Plan: Free tier (hasta 50,000 usuarios)
Métodos: Email/Password
```

### Mapas y Rutas
```yaml
Visualización: 
  - OpenStreetMap (gratis)
  - flutter_map plugin
  
Rutas óptimas (Fase 2):
  - OSRM (Open Source Routing Machine)
  - Self-hosted en Docker
```

---

## 📐 Arquitectura

### Diagrama de Componentes

```
┌─────────────────────────────────────────┐
│         Flutter Mobile App              │
│  ┌──────────┐  ┌──────────┐            │
│  │ UI Layer │  │ Services │            │
│  │  Screens │  │ Location │            │
│  │   Maps   │  │   API    │            │
│  └──────────┘  └──────────┘            │
└─────────┬───────────┬───────────────────┘
          │           │
    (GPS) │           │ (HTTPS/REST)
          │           │
          ▼           ▼
┌─────────────────────────────────────────┐
│      Firebase Authentication            │
│         (Token Validation)              │
└─────────────────────────────────────────┘
          │
          │ (JWT Token)
          ▼
┌─────────────────────────────────────────┐
│      Spring Boot REST API               │
│  ┌──────────────────────────────────┐  │
│  │ Controllers (REST Endpoints)     │  │
│  ├──────────────────────────────────┤  │
│  │ Services (Business Logic)        │  │
│  ├──────────────────────────────────┤  │
│  │ Repositories (Data Access)       │  │
│  └──────────────────────────────────┘  │
└─────────────┬───────────────────────────┘
              │
              │ (JDBC)
              ▼
┌─────────────────────────────────────────┐
│    PostgreSQL + PostGIS Database        │
│  ┌──────────────────────────────────┐  │
│  │ Table: users                     │  │
│  │ Table: locations (GEOGRAPHY)     │  │
│  │ Spatial Indexes (GIST)           │  │
│  │ Geospatial Queries               │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
              │
              │ (Fase 2)
              ▼
┌─────────────────────────────────────────┐
│         OSRM (Route Engine)             │
│      Optimal Route Calculation          │
└─────────────────────────────────────────┘
```

### Flujo de Datos

```
1. Usuario inicia tracking
   ↓
2. Foreground Service captura GPS cada 5 min
   ↓
3. App envía coordenadas + metadata a API
   ↓
4. Spring Boot valida token Firebase
   ↓
5. Backend guarda en PostgreSQL (PostGIS)
   ↓
6. Usuario solicita historial
   ↓
7. Backend ejecuta queries geoespaciales
   ↓
8. App visualiza ruta en flutter_map
```

---

## 🔋 Características Técnicas

### Tracking Inteligente

#### Configuración de Captura
```dart
LocationSettings(
  accuracy: LocationAccuracy.balanced,  // No "high", ahorra batería
  distanceFilter: 50,                   // Solo si se movió >50m
  intervalDuration: Duration(minutes: 5) // Cada 5 minutos
)
```

#### Optimización de Batería
- **Consumo estimado:** 5-10% por día
- **Modo balanceado:** Usa torre celular + WiFi + GPS
- **Distance filter:** Evita updates innecesarios
- **Pausa automática:**
  - Si batería < 15%
  - Si usuario sin movimiento (STILL activity)
  - Si usuario lo solicita

#### Foreground Service (Android)
```xml
<!-- AndroidManifest.xml -->
<service
    android:name="ForegroundService"
    android:foregroundServiceType="location"
    android:exported="false" />
```

**Características:**
- ✅ Funciona con pantalla apagada
- ✅ Notificación persistente obligatoria
- ✅ No lo mata el sistema Android
- ✅ Wake lock para GPS en background

#### iOS (Futuro - Fase 5)
```swift
// Usar "Significant Location Changes" en lugar de continuous
locationManager.startMonitoringSignificantLocationChanges()
// Consumo: <1% batería por día
```

### Datos Capturados por Punto

```json
{
  "user_id": "uuid-del-usuario",
  "latitude": -12.0464,
  "longitude": -77.0428,
  "timestamp": "2025-10-14T10:30:00Z",
  "accuracy": 15.5,        // metros
  "altitude": 150.0,       // metros sobre nivel del mar
  "speed": 5.2,            // metros/segundo
  "heading": 180.0,        // grados (0-360)
  "battery_level": 85,     // porcentaje
  "activity_type": "walking" // walking/driving/still
}
```

`activity_type` se obtiene usando la API de Activity Recognition de Google Play Services en Android (requiere el permiso `ACTIVITY_RECOGNITION`) y se deja planificado el soporte equivalente para iOS en la fase futura.

### Métricas de Performance

| Métrica | Objetivo | Crítico |
|---------|----------|---------|
| Consumo batería | ≤ 10% / 8h | ≤ 15% / 8h |
| Captura exitosa | ≥ 95% | ≥ 90% |
| API response time | < 500ms | < 1000ms |
| Precisión GPS | ≤ 30m | ≤ 50m |
| Uptime app | > 99% | > 95% |

---

## 🗄️ Base de Datos

### Esquema PostgreSQL + PostGIS

#### Tabla: users
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  firebase_uid VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
```

#### Tabla: locations (Principal)
```sql
CREATE TABLE locations (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Geometría (tipo GEOGRAPHY para cálculos reales en metros)
  geom GEOGRAPHY(Point, 4326),  -- 4326 = WGS84 (GPS estándar)
  
  -- Datos de telemetría
  timestamp TIMESTAMP NOT NULL,
  accuracy FLOAT,               -- Precisión en metros
  altitude FLOAT,               -- Metros sobre nivel del mar
  speed FLOAT,                  -- Metros por segundo
  heading FLOAT,                -- Grados (0-360, Norte = 0)
  
  -- Contexto
  battery_level INT,            -- Porcentaje 0-100
  activity_type VARCHAR(50),    -- walking, driving, still, etc.
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### Índices Críticos (OBLIGATORIOS)
```sql
-- Índice espacial (GIST) - CRÍTICO para queries geoespaciales
CREATE INDEX idx_locations_geom ON locations USING GIST(geom);

-- Índice compuesto para queries por usuario + tiempo
CREATE INDEX idx_locations_user_time ON locations(user_id, timestamp DESC);

-- Índice para búsquedas por actividad
CREATE INDEX idx_locations_activity ON locations(user_id, activity_type)
  WHERE activity_type IS NOT NULL;

-- Índice parcial para puntos recientes (optimización)
CREATE INDEX idx_locations_recent ON locations(user_id, timestamp DESC)
  WHERE timestamp > NOW() - INTERVAL '30 days';
```

### Preparación de Base de Datos (Estado Actual)

1. **Infraestructura local**  
   - Contenedor `PostgreSQL 16 + PostGIS 3.4` levantado con `database/docker-compose.yml`.  
   - Ejecutar/replicar con:
     ```bash
     cd database
     docker compose up -d        # Crea contenedor y aplica schema.sql
     docker compose ps           # Verificar estado
     ```
   - El servicio expone `localhost:5432` con credenciales (`locationapp` / `change_me`).

2. **Esquema base aplicado**  
   - Script `database/schema.sql` con extensiones (`postgis`, `postgis_topology`, `pgcrypto`), tablas (`users`, `locations`), índices críticos y trigger de `updated_at`.  
   - El mismo contenido está listo para herramientas de migración en `database/migrations/V1__base_schema.sql`.

3. **Smoke test ejecutado**  
   - Script reproducible en `database/smoke_test.sql`; se corre con:
     ```bash
     cat database/smoke_test.sql | docker compose exec -T postgres psql -U locationapp -d location_tracker
     ```
   - Inserta/actualiza el usuario `smoke@example.com` y genera un registro en `locations` (ej. `location_id = 6`).  
   - Borrar los datos de prueba si se requiere una base limpia:
     ```sql
     DELETE FROM locations WHERE user_id = (SELECT id FROM users WHERE firebase_uid = 'smoke-uid');
     DELETE FROM users WHERE firebase_uid = 'smoke-uid';
     ```

4. **Notas operativas**  
   - El contenedor permanece activo tras las pruebas; detenerlo con `docker compose down` desde `database/`.  
   - Cambiar `POSTGRES_PASSWORD` antes de exponer el servicio fuera del entorno local.  
   - Integrar `migrations/V1__base_schema.sql` como `V1` al iniciar el backend (Flyway/Liquibase).

### Backend (Estado Actual)

1. **Proyecto Spring Boot 3.5.6 / Java 21**  
   - Estructura Gradle configurada en `backend/` con dependencias clave (`spring-web`, `spring-data-jpa`, `hibernate-spatial`, `springdoc`, `lombok`, `spring-boot-starter-validation`, `postgresql`, `jts-core`).  
   - Archivo principal `LocationBackendApplication.java` inicializa el servicio y expone endpoints REST en `/api`.  
   - Repositorios JPA (`UserRepository`, `LocationRecordRepository`) y entidades (`User`, `LocationRecord`) mapean PostGIS (`@JdbcTypeCode(SqlTypes.GEOMETRY)`).

2. **Servicios y Controladores**  
   - `UserController` (`POST /api/users`, `GET /api/users`, `GET /api/users/{firebaseUid}`) maneja alta/consulta de usuarios vinculados a Firebase.  
   - `LocationController` (`POST /api/locations`, `GET /api/locations/history`, `GET /api/locations/distance`) registra puntos, historial y distancia diaria calculada con `ST_Distance`.  
   - `LocationService` usa `GeometryFactory (SRID 4326)` y consultas nativas para sumar distancias.  
   - `GlobalExceptionHandler` estandariza errores de validación (`400`) y recursos inexistentes (`404`).

3. **Ejecución local (sin Gradle instalado globalmente)**  
   ```bash
   cd backend
   # Usa la distribución descargada gradle-8.6/ y guarda caches en la carpeta del proyecto
   GRADLE_USER_HOME=$PWD/.gradle ./gradle-8.6/bin/gradle bootRun
   ```
   - Logs clave esperados:
     - `HikariPool-1 - Start completed`
     - `Tomcat started on port 8080`
     - `Started LocationBackendApplication`
   - Endpoints de verificación:
     ```bash
     curl http://localhost:8080/api/health/db        # {"status":"UP","db":1}
     curl http://localhost:8080/swagger-ui           # Documentación interactiva
     ```
   - Detener el backend con `Ctrl+C` en la terminal que ejecuta `bootRun`.

4. **Notas operativas**  
   - El backend depende de la base `location_tracker` levantada con `docker compose up -d` en `database/`.  
   - Cualquier error de permisos de ubicación PostGIS se resuelve usando el dialecto `org.hibernate.spatial.dialect.postgis.PostgisPG95Dialect` (configurado en `application.yml`).  
   - Validaciones (`@Valid`) requieren `spring-boot-starter-validation`, ya incorporado.

### Queries Principales

#### 1. Guardar Ubicación
```sql
INSERT INTO locations (
  user_id, 
  geom, 
  timestamp, 
  accuracy, 
  speed, 
  battery_level,
  activity_type
) VALUES (
  $1,  -- user_id
  ST_SetSRID(ST_MakePoint($2, $3), 4326),  -- lng, lat
  $4,  -- timestamp
  $5,  -- accuracy
  $6,  -- speed
  $7,  -- battery
  $8   -- activity
) RETURNING id;
```

#### 2. Obtener Historial de un Día
```sql
SELECT 
  id,
  ST_Y(geom::geometry) as latitude,
  ST_X(geom::geometry) as longitude,
  timestamp,
  accuracy,
  speed,
  battery_level,
  activity_type
FROM locations
WHERE user_id = $1
  AND timestamp >= $2  -- inicio del día
  AND timestamp < $3   -- fin del día
ORDER BY timestamp ASC;
```

#### 3. Calcular Distancia Recorrida en un Día
```sql
WITH ordered_points AS (
  SELECT 
    geom,
    timestamp,
    LAG(geom) OVER (ORDER BY timestamp) as prev_geom
  FROM locations
  WHERE user_id = $1
    AND timestamp::date = $2
)
SELECT 
  COALESCE(
    SUM(ST_Distance(geom, prev_geom)) / 1000,  -- Convertir a km
    0
  ) as total_km
FROM ordered_points
WHERE prev_geom IS NOT NULL;
```

#### 4. Lugares Más Visitados (Heatmap)
```sql
SELECT 
  ST_AsGeoJSON(ST_Centroid(ST_Collect(geom::geometry)))::json as center,
  COUNT(*) as visit_count,
  MIN(timestamp) as first_visit,
  MAX(timestamp) as last_visit,
  EXTRACT(EPOCH FROM (MAX(timestamp) - MIN(timestamp)))/3600 as hours_spent
FROM locations
WHERE user_id = $1
  AND timestamp > NOW() - INTERVAL '30 days'
GROUP BY ST_SnapToGrid(geom::geometry, 0.001)  -- ~100m de precisión
HAVING COUNT(*) > 5  -- Mínimo 5 visitas
ORDER BY visit_count DESC
LIMIT 10;
```

#### 5. Puntos Cerca de una Ubicación
```sql
SELECT 
  id,
  ST_Y(geom::geometry) as latitude,
  ST_X(geom::geometry) as longitude,
  timestamp,
  ST_Distance(
    geom,
    ST_SetSRID(ST_MakePoint($2, $3), 4326)
  ) as distance_meters
FROM locations
WHERE user_id = $1
  AND ST_DWithin(
    geom,
    ST_SetSRID(ST_MakePoint($2, $3), 4326),
    500  -- Radio en metros
  )
ORDER BY distance_meters
LIMIT 20;
```

#### 6. Ruta del Día como LineString (GeoJSON)
```sql
SELECT 
  ST_AsGeoJSON(ST_MakeLine(geom::geometry ORDER BY timestamp))::json as route_geojson,
  COUNT(*) as point_count,
  MIN(timestamp) as start_time,
  MAX(timestamp) as end_time
FROM locations
WHERE user_id = $1
  AND timestamp::date = $2
GROUP BY user_id
HAVING COUNT(*) > 1;
```

#### 7. Estadísticas Semanales
```sql
SELECT 
  DATE(timestamp) as day,
  COUNT(*) as points_captured,
  ROUND(
    SUM(ST_Distance(geom, LAG(geom) OVER (ORDER BY timestamp))) / 1000
  , 2) as distance_km,
  MIN(battery_level) as min_battery,
  MAX(battery_level) as max_battery
FROM locations
WHERE user_id = $1
  AND timestamp > NOW() - INTERVAL '7 days'
GROUP BY DATE(timestamp)
ORDER BY day DESC;
```

### Mantenimiento y Optimización

#### Particionamiento (Para escala)
```sql
-- Si tienes millones de registros, particiona por mes
CREATE TABLE locations_2025_10 PARTITION OF locations
FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');

CREATE TABLE locations_2025_11 PARTITION OF locations
FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
```

#### Vacuum y Analyze Automático
```sql
-- PostgreSQL lo hace automático, pero puedes forzarlo
VACUUM ANALYZE locations;

-- Para liberar espacio después de borrar datos antiguos
VACUUM FULL locations;
```

#### Eliminar Datos Antiguos (GDPR compliance)
```sql
-- Eliminar ubicaciones > 1 año
DELETE FROM locations
WHERE timestamp < NOW() - INTERVAL '1 year';

-- O archivar en tabla histórica
INSERT INTO locations_archive
SELECT * FROM locations
WHERE timestamp < NOW() - INTERVAL '1 year';

DELETE FROM locations
WHERE timestamp < NOW() - INTERVAL '1 year';
```

---

## 📅 Plan de Desarrollo

### 👥 Equipo: 2 Personas | ⏱️ Tiempo: 3 Semanas

---

### 📆 SEMANA 1: Setup e Implementación Base

#### **Persona 1 - Backend & Infraestructura**

##### Día 1-2: Setup del Servidor
```bash
# 1. Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 2. Levantar PostgreSQL + PostGIS
docker run --name location-postgres \
  -e POSTGRES_USER=locationapp \
  -e POSTGRES_PASSWORD=change_me \
  -e POSTGRES_DB=location_tracker \
  -p 5432:5432 \
  -v /var/lib/postgresql/data:/var/lib/postgresql/data \
  --restart always \
  -d postgis/postgis:16-3.4

# 3. Verificar
docker ps
docker logs location-postgres
```

##### Día 3-4: Estructura de Base de Datos
```sql
-- Conectarse
docker exec -it location-postgres psql -U locationapp -d location_tracker

-- Habilitar PostGIS
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_topology;

-- Verificar
SELECT PostGIS_version();

-- Crear tablas (usar scripts de sección "Base de Datos")
-- Crear índices
-- Poblar datos de prueba
```

##### Día 5-7: API Backend Spring Boot
```bash
# 1. Crear proyecto en https://start.spring.io/
# 2. Configurar dependencias (ver sección Stack)
# 3. Implementar:
#    - Entities (User, Location)
#    - Repositories (LocationRepository)
#    - Services (LocationService)
#    - Controllers (LocationController)
#    - Security (Firebase JWT validation)
```

**Endpoints a implementar:**
- `POST /api/locations` - Guardar ubicación
- `GET /api/locations/history` - Historial
- `GET /api/stats/distance` - Distancia del día

**Testing:**
```bash
# Test con curl
curl -X POST http://localhost:8080/api/locations \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": -12.0464,
    "longitude": -77.0428,
    "timestamp": "2025-10-14T10:30:00Z",
    "accuracy": 15.5,
    "speed": 5.2,
    "batteryLevel": 85
  }'
```

---

#### **Persona 2 - Frontend Flutter**

##### Día 1-2: Setup Proyecto Flutter
```bash
# 1. Crear proyecto
flutter create location_tracker_app
cd location_tracker_app

# 2. Agregar dependencias en pubspec.yaml
# (ver sección Stack Tecnológico)

# 3. Verificar
flutter doctor
flutter pub get
```

##### Día 3-4: Configuración Android & Firebase

**android/app/src/main/AndroidManifest.xml:**
```xml
<manifest>
    <!-- Permisos -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
    
    <application>
        <!-- Foreground service -->
        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="location"
            android:exported="false" />
    </application>
</manifest>
```

**Configurar Firebase:**
1. Crear proyecto en Firebase Console
2. Agregar app Android
3. Descargar `google-services.json` → `android/app/`
4. Configurar `android/build.gradle` y `android/app/build.gradle`

##### Día 5-7: Implementación Core

**Estructura de carpetas:**
```
lib/
├── main.dart
├── config/
│   └── constants.dart
├── services/
│   ├── location_service.dart
│   ├── api_service.dart
│   └── auth_service.dart
├── models/
│   ├── location_point.dart
│   └── user_model.dart
├── screens/
│   ├── login_screen.dart
│   ├── map_screen.dart
│   └── history_screen.dart
├── widgets/
│   ├── location_map.dart
│   └── stats_card.dart
└── utils/
    └── date_helpers.dart
```

**Implementar:**
1. `LocationService` - Captura GPS y foreground service
2. `ApiService` - Comunicación con backend
3. `AuthService` - Login con Firebase
4. `MapScreen` - Visualización básica

---

### 📆 SEMANA 2: Integración & Testing

#### Día 8-9: Conexión End-to-End
**Ambos trabajando juntos:**
- Conectar Flutter con Spring Boot API
- Configurar Firebase en backend (validación tokens)
- Probar flujo completo:
  1. Login → Token
  2. Captura GPS → Envío a API
  3. Query historial → Visualización

**Checklist:**
- [ ] Login funcional
- [ ] Captura GPS cada 5 min
- [ ] Datos llegando a PostgreSQL
- [ ] Query historial funcionando
- [ ] Mapa mostrando ruta

#### Día 10-11: Testing de Tracking Continuo
**Pruebas:**
- Dejar app corriendo 4+ horas
- Monitorear consumo de batería
- Verificar todos los puntos capturados
- Probar con/sin movimiento
- Probar con pantalla apagada

**Métricas a medir:**
```
- Puntos capturados vs esperados: ___%
- Batería consumida en 4h: ___%
- Precisión promedio: ___m
- Crashes o errores: ___
- Response time API: ___ms
```

#### Día 12: Optimizaciones
**Basado en testing:**
- Ajustar `distanceFilter` (50m, 100m, 200m?)
- Optimizar frecuencia si batería crítica
- Mejorar queries lentas en backend
- Cachear datos en app

#### Día 13: Features de Optimización
**Implementar:**
- Pausa automática si batería < 15%
- Detector de actividad (pausa si STILL)
- Configuración de frecuencia por usuario
- Modo "eco" (reduce precisión)

#### Día 14: Testing en Dispositivos Reales
**Probar en múltiples dispositivos:**
- Android 10, 11, 12, 13, 14
- Diferentes fabricantes (Samsung, Xiaomi, etc.)
- Con/sin Google Play Services
- Diferentes condiciones de red

---

### 📆 SEMANA 3: Features Adicionales & Polish

#### Persona 1 - Backend (Día 15-21)

##### Features adicionales:
```java
// 1. Endpoint de estadísticas avanzadas
GET /api/stats/weekly?userId=X
GET /api/stats/places/frequent?userId=X&days=30

// 2. Export de datos
GET /api/export/csv?userId=X&start=&end=
GET /api/export/geojson?userId=X&start=&end=

// 3. Configuración de usuario
PUT /api/user/settings
{
  "trackingFrequency": 300,  // segundos
  "minBatteryLevel": 15,
  "pauseWhenStill": true
}
```

##### Optimizaciones DB:
- Indices adicionales según queries lentas
- Connection pooling configurado
- Query caching para estadísticas

##### Preparar OSRM (opcional):
```bash
# Descargar datos de Perú
wget http://download.geofabrik.de/south-america/peru-latest.osm.pbf

# Procesar
docker run -t -v $(pwd):/data ghcr.io/project-osrm/osrm-backend osrm-extract -p /opt/car.lua /data/peru-latest.osm.pbf
docker run -t -v $(pwd):/data ghcr.io/project-osrm/osrm-backend osrm-partition /data/peru-latest.osrm
docker run -t -v $(pwd):/data ghcr.io/project-osrm/osrm-backend osrm-customize /data/peru-latest.osrm

# Iniciar servidor
docker run -t -i -p 5000:5000 -v $(pwd):/data ghcr.io/project-osrm/osrm-backend osrm-routed --algorithm mld /data/peru-latest.osrm
```

---

#### Persona 2 - Frontend (Día 15-21)

##### Pantallas adicionales:

**1. Pantalla de Historial:**
```dart
// history_screen.dart
- DateRangePicker para seleccionar fechas
- Lista de días con:
  * Distancia recorrida
  * Tiempo activo
  * Puntos capturados
- Tap en día → ver mapa de ese día
```

**2. Dashboard de Estadísticas:**
```dart
// dashboard_screen.dart
- Distancia total (semanal, mensual)
- Lugares más visitados (top 5)
- Gráfico de actividad por día
- Promedio de batería consumida
```

**3. Configuración:**
```dart
// settings_screen.dart
- Frecuencia de tracking (slider)
- Pausa por batería (switch + nivel)
- Pausa si no hay movimiento (switch)
- Eliminar datos antiguos
- Exportar datos
- Cerrar sesión
```

##### Mejoras UI/UX:
- Animaciones de transición
- Loading states
- Error handling con mensajes claros
- Dark mode (opcional)
- Iconos y colores consistentes

##### Testing:
- Widget tests de pantallas principales
- Integration tests del flujo completo

---

### 🎯 Entregables Finales (Día 21)

#### Documentación:
- [ ] README.md con instrucciones de instalación
- [ ] API documentation (endpoints, request/response)
- [ ] Guía de despliegue en servidor
- [ ] Guía de uso para testers

#### Código:
- [ ] Repositorio Git organizado
- [ ] Backend Spring Boot completo
- [ ] App Flutter compilada (.apk)
- [ ] Scripts SQL de base de datos
- [ ] Docker Compose para infraestructura

#### Testing:
- [ ] Reporte de pruebas (batería, precisión, estabilidad)
- [ ] Lista de bugs conocidos
- [ ] Screenshots de la app funcionando

---

## 🚀 Guía de Setup

### Requisitos Previos

#### Servidor:
- Ubuntu 20.04+ o similar
- 4GB RAM mínimo (8GB recomendado)
- 20GB almacenamiento
- Docker instalado
- Puerto 5432 (PostgreSQL) y 8080 (API) abiertos

#### Desarrollo:
- Java 21 (backend)
- Gradle 8.6+ (backend)
- Flutter 3.16+ (frontend)
- Android Studio (frontend)
- Git

---

### Setup Backend (Spring Boot)

#### 1. Preparar entorno
```bash
# Requiere JDK 21 y Gradle 8.6+
cd backend

# Opcional: exportar credenciales (coinciden con database/docker-compose.yml)
export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/location_tracker
export SPRING_DATASOURCE_USERNAME=locationapp
export SPRING_DATASOURCE_PASSWORD=change_me
```

#### 2. Ejecutar aplicación
```bash
# Arrancar el backend apuntando a la base PostGIS
gradle bootRun

# Con wrapper (si se agrega)
# ./gradlew bootRun
```

#### 3. Verificar conexión
```bash
# Endpoint de salud que ejecuta SELECT 1
curl http://localhost:8080/api/health/db
# Respuesta esperada: {"status":"UP","db":1}

# Documentación OpenAPI
# Abrir en navegador: http://localhost:8080/swagger-ui
```

---

### Setup Frontend (Flutter)

#### 1. Clonar y configurar
```bash
git clone <repo-url>
cd location_tracker_app

flutter pub get
```

#### 2. Configurar Firebase
```bash
# Descargar google-services.json de Firebase Console
# Colocar en: android/app/google-services.json

# Configurar Firebase en código
# Editar: lib/config/constants.dart
```

#### 3. Configurar URL del backend
```dart
// lib/config/constants.dart
class Constants {
  static const String apiBaseUrl = 'http://TU_IP_SERVIDOR:8080/api';
  // O en producción:
  // static const String apiBaseUrl = 'https://api.tudominio.com/api';
}
```

#### 4. Ejecutar en dispositivo
```bash
# Verificar dispositivo conectado
flutter devices

# Ejecutar
  flutter run  
  flutter run -d emulator-5554  # tras iniciar ~/Android/Sdk/emulator/emulator -avd flutter_emulator

# O compilar APK
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

---

### Setup Base de Datos (PostgreSQL + PostGIS)

#### Docker Compose (Recomendado)
```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgis/postgis:16-3.4
    container_name: postgis-location
    environment:
      POSTGRES_DB: location_tracker
      POSTGRES_USER: locationapp
      POSTGRES_PASSWORD: CAMBIAR_PASSWORD
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: always

  api:
    build: ./location-api
    container_name: location-api
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/location_tracker
      SPRING_DATASOURCE_USERNAME: locationapp
      SPRING_DATASOURCE_PASSWORD: CAMBIAR_PASSWORD
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    restart: always

volumes:
  postgres_data:
```

```bash
# Levantar todo
docker-compose up -d

# Ver logs
docker-compose logs -f

# Detener
docker-compose down
```

#### Script de inicialización (init.sql)
```sql
-- Este archivo se ejecuta automáticamente al crear el contenedor

-- Habilitar PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Crear tablas
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  firebase_uid VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE locations (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  geom GEOGRAPHY(Point, 4326),
  timestamp TIMESTAMP NOT NULL,
  accuracy FLOAT,
  altitude FLOAT,
  speed FLOAT,
  heading FLOAT,
  battery_level INT,
  activity_type VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Crear índices
CREATE INDEX idx_locations_geom ON locations USING GIST(geom);
CREATE INDEX idx_locations_user_time ON locations(user_id, timestamp DESC);
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);

-- Datos de prueba (opcional)
-- INSERT INTO users (email, firebase_uid) VALUES ('test@example.com', 'test-uid-123');
```

---

## 💰 Costos y Recursos

### Costos Mensuales (Estimados)

| Servicio | Plan | Costo |
|----------|------|-------|
| Servidor propio | Ya disponible | $0 |
| Firebase Auth | Free tier | $0 (hasta 50k usuarios) |
| OpenStreetMap | Gratis | $0 |
| Dominio | .com | $12/año = $1/mes |
| SSL Certificate | Let's Encrypt | $0 |
| **TOTAL** | | **~$1/mes** |

### Escalabilidad - Costos Futuros

Si necesitas escalar (miles de usuarios):

| Usuarios Activos | Servidor VPS | Base de Datos | Total/mes |
|------------------|--------------|---------------|-----------|
| 100 | Actual | Actual | $0 |
| 1,000 | DigitalOcean 4GB ($24) | Actual | $24 |
| 10,000 | DigitalOcean 8GB ($48) | Managed DB ($15) | $63 |
| 100,000 | AWS EC2 ($100+) | AWS RDS ($150+) | $250+ |

### Recursos del Servidor

**Configuración Mínima (PoC):**
- CPU: 2 cores
- RAM: 4GB
- Storage: 20GB SSD
- Bandwidth: Ilimitado

**Configuración Recomendada:**
- CPU: 4 cores
- RAM: 8GB
- Storage: 50GB SSD
- Bandwidth: Ilimitado

**Crecimiento de Storage:**
```
1 punto GPS = ~150 bytes en DB
1 usuario = 288 puntos/día (cada 5 min)
1 usuario = ~43KB/día = 1.3MB/mes

100 usuarios = 130MB/mes
1,000 usuarios = 1.3GB/mes
10,000 usuarios = 13GB/mes
```

---

## 📱 Código de Referencia

### Backend - Spring Boot

- **UserController (`/api/users`)**
  - `POST /api/users` crea o actualiza un usuario a partir de `firebaseUid` + email.
  - `GET /api/users/{firebaseUid}` recupera el usuario registrado.
  - `GET /api/users` lista todos los usuarios registrados (útil para debugging).

- **LocationController (`/api/locations`)**
  - `POST /api/locations` guarda un punto geoespacial. El backend convierte `latitude/longitude` en un `Point` SRID 4326 usando JTS + PostGIS.
  - `GET /api/locations/history?firebaseUid=UID&start=2025-10-15T00:00:00Z&end=2025-10-16T00:00:00Z` devuelve los puntos en el rango y la distancia (km) calculada con PostGIS.
  - `GET /api/locations/distance?firebaseUid=UID&date=2025-10-15` calcula distancia diaria (km) usando `ST_Distance` sobre `geography`.

- **Lógica clave**
  - `LocationService` se apoya en `GeometryFactory` (SRID 4326) para crear `Point` y delega en consultas nativas de PostGIS para cálculo de distancias acumuladas.
  - `LocationRecordRepository` incorpora un `WINDOW FUNCTION + ST_Distance` para sumar tramos consecutivos en la base.
  - `UserService` centraliza la búsqueda/creación de usuarios vinculados a Firebase.

- **Validación y manejo de errores**
  - Se agregó `spring-boot-starter-validation` para validar DTOs (`@NotBlank`, `@DecimalMin`, etc.).
  - `GlobalExceptionHandler` traduce errores de validación a `400` y recursos inexistentes a `404`.

Fragmento de request para crear ubicación:

```bash
curl -X POST http://localhost:8080/api/locations \
  -H "Content-Type: application/json" \
  -d '{
        "firebaseUid": "uid-123",
        "latitude": -12.0464,
        "longitude": -77.0428,
        "timestamp": "2025-10-15T12:00:00Z",
        "batteryLevel": 88,
        "activityType": "walking"
      }'
```

Respuesta resumida:

```json
{
  "id": 42,
  "latitude": -12.0464,
  "longitude": -77.0428,
  "timestamp": "2025-10-15T12:00:00Z",
  "batteryLevel": 88,
  "activityType": "walking"
}
```

---

### Frontend - Flutter

#### location_service.dart
```dart
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'api_service.dart';

class LocationService {
  static bool _isTracking = false;
  
  /// Iniciar tracking de ubicación
  static Future<void> startTracking() async {
    if (_isTracking) return;
    
    // Verificar permisos
    bool hasPermission = await _checkPermissions();
    if (!hasPermission) {
      throw Exception('Permisos de ubicación denegados');
    }
    
    // Configurar foreground task
    await FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_tracking',
        channelName: 'Tracking de Ubicación',
        channelDescription: 'Guardando tu ubicación cada 5 minutos',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 300000, // 5 minutos en milisegundos
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    
    // Iniciar servicio
    bool started = await FlutterForegroundTask.startService(
      notificationTitle: 'Tracking activo',
      notificationText: 'Guardando ubicación cada 5 minutos',
      callback: startCallback,
    );
    
    if (started) {
      _isTracking = true;
    }
  }
  
  /// Detener tracking
  static Future<void> stopTracking() async {
    await FlutterForegroundTask.stopService();
    _isTracking = false;
  }
  
  /// Obtener ubicación actual una vez
  static Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return null;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.balanced,
      );
      
      return position;
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      return null;
    }
  }
  
  /// Verificar permisos
  static Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission != LocationPermission.denied &&
           permission != LocationPermission.deniedForever;
  }
  
  /// Estado del tracking
  static bool get isTracking => _isTracking;
}

/// Callback del foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

/// Handler que se ejecuta cada 5 minutos
class LocationTaskHandler extends TaskHandler {
  int _eventCount = 0;
  
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    print('Location tracking started at $timestamp');
  }
  
  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    _eventCount++;
    print('Location event #$_eventCount at $timestamp');
    
    try {
      // Obtener ubicación
      Position? position = await LocationService.getCurrentLocation();
      
      if (position != null) {
        // Obtener nivel de batería
        int batteryLevel = await _getBatteryLevel();
        
        // Verificar si debe pausar por batería baja
        if (batteryLevel < 15) {
          print('Batería baja ($batteryLevel%), pausando tracking');
          await LocationService.stopTracking();
          return;
        }
        
        // Enviar al backend
        bool success = await ApiService.saveLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          altitude: position.altitude,
          speed: position.speed,
          heading: position.heading,
          timestamp: DateTime.now(),
          batteryLevel: batteryLevel,
        );
        
        if (success) {
          print('Ubicación guardada: ${position.latitude}, ${position.longitude}');
          
          // Actualizar notificación
          FlutterForegroundTask.updateService(
            notificationText: 'Última ubicación: ${DateTime.now().toString().substring(11, 16)}',
          );
        } else {
          print('Error guardando ubicación en el servidor');
        }
      } else {
        print('No se pudo obtener ubicación GPS');
      }
    } catch (e) {
      print('Error en LocationTaskHandler: $e');
    }
  }
  
  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print('Location tracking stopped at $timestamp');
  }
  
  /// Obtener nivel de batería
  Future<int> _getBatteryLevel() async {
    // Implementar con battery_plus
    return 100; // Placeholder
  }
}
```

#### api_service.dart
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'auth_service.dart';

class ApiService {
  /// Guardar ubicación en el backend
  static Future<bool> saveLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
    double? altitude,
    double? speed,
    double? heading,
    required DateTime timestamp,
    int? batteryLevel,
    String? activityType,
  }) async {
    try {
      String? token = await AuthService.getIdToken();
      if (token == null) return false;
      
      final response = await http.post(
        Uri.parse('${Constants.apiBaseUrl}/locations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'altitude': altitude,
          'speed': speed,
          'heading': heading,
          'timestamp': timestamp.toIso8601String(),
          'batteryLevel': batteryLevel,
          'activityType': activityType,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error guardando ubicación: $e');
      return false;
    }
  }
  
  /// Obtener historial de ubicaciones
  static Future<List<LocationPoint>> getHistory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      String? token = await AuthService.getIdToken();
      if (token == null) return [];
      
      final response = await http.get(
        Uri.parse(
          '${Constants.apiBaseUrl}/locations/history'
          '?startDate=${startDate.toIso8601String()}'
          '&endDate=${endDate.toIso8601String()}'
        ),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => LocationPoint.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo historial: $e');
      return [];
    }
  }
  
  /// Obtener distancia recorrida en un día
  static Future<double> getDistanceForDay(DateTime date) async {
    try {
      String? token = await AuthService.getIdToken();
      if (token == null) return 0.0;
      
      final response = await http.get(
        Uri.parse(
          '${Constants.apiBaseUrl}/stats/distance'
          '?date=${date.toIso8601String()}'
        ),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        return double.parse(response.body);
      }
      
      return 0.0;
    } catch (e) {
      print('Error obteniendo distancia: $e');
      return 0.0;
    }
  }
}
```

#### map_screen.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../models/location_point.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<LatLng> routePoints = [];
  bool isTracking = false;
  bool isLoading = true;
  double distanceKm = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadTodayRoute();
    isTracking = LocationService.isTracking;
  }
  
  Future<void> _loadTodayRoute() async {
    setState(() => isLoading = true);
    
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));
    
    try {
      // Obtener puntos del día
      List<LocationPoint> points = await ApiService.getHistory(
        startDate: startOfDay,
        endDate: endOfDay,
      );
      
      // Obtener distancia
      double distance = await ApiService.getDistanceForDay(startOfDay);
      
      setState(() {
        routePoints = points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        distanceKm = distance;
        isLoading = false;
      });
    } catch (e) {
      print('Error cargando ruta: $e');
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _toggleTracking() async {
    if (isTracking) {
      await LocationService.stopTracking();
      setState(() => isTracking = false);
    } else {
      try {
        await LocationService.startTracking();
        setState(() => isTracking = true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Ubicación'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTodayRoute,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            options: MapOptions(
              center: routePoints.isNotEmpty 
                  ? routePoints.first 
                  : LatLng(-12.0464, -77.0428),
              zoom: 13.0,
            ),
            children: [
              // Capa de tiles (OpenStreetMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.location_tracker',
              ),
              
              // Línea de ruta
              if (routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              
              // Marcadores
              if (routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    // Punto inicial (verde)
                    Marker(
                      point: routePoints.first,
                      width: 40,
                      height: 40,
                      builder: (ctx) => Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                    // Punto final/actual (rojo)
                    Marker(
                      point: routePoints.last,
                      width: 40,
                      height: 40,
                      builder: (ctx) => Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Indicador de carga
          if (isLoading)
            Center(
              child: CircularProgressIndicator(),
            ),
          
          // Card de estadísticas
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hoy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Puntos capturados'),
                            Text(
                              '${routePoints.length}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Distancia'),
                            Text(
                              '${distanceKm.toStringAsFixed(2)} km',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      
      // Botón de tracking
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleTracking,
        label: Text(isTracking ? 'Detener' : 'Iniciar'),
        icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
        backgroundColor: isTracking ? Colors.red : Colors.green,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
```

---

## 🚀 Roadmap

### Fase 1: PoC (Semanas 1-3) ✅
**Objetivo:** Validar concepto con funcionalidad mínima

- [x] Setup infraestructura (servidor, DB, Firebase)
- [x] Backend Spring Boot con endpoints básicos
- [x] App Flutter con tracking y visualización
- [x] Integración end-to-end funcional
- [x] Testing de batería y precisión

**Entregable:** App Android funcional + Backend desplegado

---

### Fase 2: Features Core (Mes 2)
**Objetivo:** Completar funcionalidades principales

#### Backend:
- [ ] Endpoint de estadísticas avanzadas
- [ ] Export de datos (CSV, GeoJSON)
- [ ] API de configuración de usuario
- [ ] Optimización de queries (indices, caching)
- [ ] Logging y monitoreo

#### Frontend:
- [ ] Pantalla de historial con calendario
- [ ] Dashboard de estadísticas
- [ ] Configuración de tracking
- [ ] Notificaciones push
- [ ] Manejo de errores robusto

#### Infraestructura:
- [ ] HTTPS con SSL (Let's Encrypt)
- [ ] Backup automático de DB
- [ ] CI/CD pipeline básico

**Entregable:** App completa lista para beta testers

---

### Fase 3: Análisis Avanzado (Mes 3)
**Objetivo:** Rutas óptimas y análisis inteligente

#### Rutas:
- [ ] Integración OSRM (self-hosted)
- [ ] Cálculo de rutas óptimas entre puntos
- [ ] Comparación ruta real vs óptima
- [ ] Sugerencias de mejora

#### Análisis:
- [ ] Detección automática de "hogar" y "trabajo"
- [ ] Patrones de movimiento (días laborales vs fines de semana)
- [ ] Heatmap de zonas más frecuentadas
- [ ] Predicción de próxima ubicación

#### UI:
- [ ] Visualización de rutas optimizadas
- [ ] Gráficos y reportes
- [ ] Comparativas temporales

**Entregable:** Sistema de análisis funcional

---

### Fase 4: iOS (Mes 4)
**Objetivo:** Soporte multiplataforma completo

- [ ] Port a iOS de la app Flutter
- [ ] Configuración de permisos iOS
- [ ] Background location (significant changes)
- [ ] TestFlight beta
- [ ] App Store submission

**Entregable:** App iOS en TestFlight

---

### Fase 5: Features Premium (Mes 5+)
**Objetivo:** Monetización y features avanzadas

#### Social:
- [ ] Compartir ubicación en tiempo real
- [ ] Grupos/familias
- [ ] Chat entre miembros del grupo

#### Geofencing:
- [ ] Crear zonas personalizadas
- [ ] Alertas al entrar/salir
- [ ] Notificaciones automáticas

#### Integración:
- [ ] Export a Google Timeline
- [ ] Import desde otras apps
- [ ] API pública para terceros

#### Gamificación:
- [ ] Logros por distancia
- [ ] Ranking entre amigos
- [ ] Desafíos semanales

**Entregable:** App completa con features premium

---

### Fase 6: Escalabilidad (Mes 6+)
**Objetivo:** Preparar para miles de usuarios

- [ ] Migrar a Kubernetes
- [ ] Load balancing
- [ ] CDN para assets
- [ ] Redis caching
- [ ] Elasticsearch para búsquedas
- [ ] Monitoreo con Prometheus/Grafana
- [ ] Auto-scaling

**Entregable:** Infraestructura escalable

---

## 📈 Métricas de Éxito

### Técnicas (PoC)
- ✅ Consumo batería ≤ 10% en 8 horas
- ✅ Tasa de captura ≥ 95%
- ✅ API latency < 500ms
- ✅ Precisión GPS ≤ 30m promedio
- ✅ Uptime ≥ 99%
- ✅ 0 crashes en 24h continuas

### Producto (Post-PoC)
- 📊 Usuarios activos diarios (DAU)
- 📊 Retención D1, D7, D30
- 📊 Tiempo promedio de sesión
- 📊 Frecuencia de uso (días/semana)
- 📊 Net Promoter Score (NPS)

### Negocio (Futuro)
- 💰 Tasa de conversión free → premium
- 💰 Costo de adquisición (CAC)
- 💰 Lifetime value (LTV)
- 💰 Churn rate

---

## 🔒 Consideraciones de Seguridad y Privacidad

### Seguridad Técnica

#### API:
- ✅ HTTPS obligatorio en producción
- ✅ Validación de tokens JWT (Firebase)
- ✅ Rate limiting (100 req/min por usuario)
- ✅ Input validation y sanitization
- ✅ SQL injection prevention (prepared statements)
- ✅ CORS configurado correctamente

#### Base de Datos:
- ✅ Credenciales en variables de entorno
- ✅ Backup automático diario
- ✅ Encriptación en reposo (PostgreSQL)
- ✅ Acceso restringido por firewall

#### App:
- ✅ Almacenamiento seguro de tokens
- ✅ HTTPS pinning (opcional)
- ✅ Obfuscación de código (release)

### Privacidad del Usuario

#### Transparencia:
- ✅ Notificación visible cuando tracking activo
- ✅ Explicar claramente qué datos se capturan
- ✅ Política de privacidad accesible
- ✅ Términos y condiciones

#### Control del Usuario:
- ✅ Pausar/reanudar tracking fácilmente
- ✅ Eliminar historial (por día, por rango, todo)
- ✅ Exportar sus propios datos
- ✅ Eliminar cuenta completa

#### GDPR Compliance (si aplica):
- ✅ Derecho al olvido
- ✅ Derecho a la portabilidad
- ✅ Consentimiento explícito
- ✅ Minimización de datos
- ✅ Retención limitada (1 año por defecto)

### Recomendaciones Legales

**IMPORTANTE:** Consultar con abogado antes de lanzar. Temas a revisar:
- Política de privacidad
- Términos de servicio
- Compliance con leyes locales
- Responsabilidad por uso indebido
- Protección de datos de menores

---

## 🐛 Troubleshooting

### Problemas Comunes

#### 1. GPS no obtiene ubicación
**Síntomas:** `getCurrentLocation()` retorna null o timeout

**Soluciones:**
```dart
// Verificar permisos
await Geolocator.checkPermission()

// Verificar si GPS está activado
bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

// Aumentar timeout
await Geolocator.getCurrentPosition(
  timeLimit: Duration(seconds: 30)
);
```

#### 2. Foreground service se detiene
**Síntomas:** Tracking se para solo

**Soluciones:**
- Verificar batería no en modo ahorro extremo
- Verificar app no en "Doze mode"
- Agregar a whitelist de batería
- Usar `allowWakeLock: true`

#### 3. API retorna 401 Unauthorized
**Síntomas:** Requests fallan con 401

**Soluciones:**
```dart
// Verificar token no expiró
String? token = await FirebaseAuth.instance.currentUser?.getIdToken(true);

// Verificar formato header
'Authorization': 'Bearer $token'  // con "Bearer "
```

#### 4. Queries PostGIS lentas
**Síntomas:** Endpoints tardan >2 segundos

**Soluciones:**
```sql
-- Verificar índices existen
\d locations

-- Recrear índice espacial
REINDEX INDEX idx_locations_geom;

-- Analyze tabla
ANALYZE locations;

-- Ver query plan
EXPLAIN ANALYZE SELECT ...;
```

#### 5. Consumo alto de batería
**Síntomas:** >15% en 8 horas

**Soluciones:**
- Cambiar a `LocationAccuracy.low` o `balanced`
- Aumentar `distanceFilter` a 100-200m
- Aumentar intervalo a 10 minutos
- Verificar no hay location listeners duplicados

---

## 📞 Contacto y Soporte

### Durante Desarrollo (PoC)
- **Persona 1 (Backend):** [email/slack]
- **Persona 2 (Frontend):** [email/slack]
- **Reuniones diarias:** [horario]
- **Repositorio:** [GitHub URL]
- **Documentación:** [Confluence/Notion URL]

### Post-PoC
- **Email soporte:** support@tudominio.com
- **Documentación API:** https://api.tudominio.com/docs
- **Status page:** https://status.tudominio.com
- **GitHub Issues:** [repo URL]/issues

---

## 📚 Referencias y Recursos

### Documentación Oficial
- **Flutter:** https://docs.flutter.dev
- **Spring Boot:** https://docs.spring.io/spring-boot/
- **PostgreSQL:** https://www.postgresql.org/docs/
- **PostGIS:** https://postgis.net/documentation/
- **Firebase:** https://firebase.google.com/docs

### Librerías Clave
- **geolocator:** https://pub.dev/packages/geolocator
- **flutter_map:** https://pub.dev/packages/flutter_map
- **Hibernate Spatial:** https://docs.jboss.org/hibernate/orm/current/userguide/html_single/Hibernate_User_Guide.html#spatial

### Tutoriales y Guías
- **PostGIS Tutorial:** https://postgis.net/workshops/postgis-intro/
- **Flutter Background Location:** https://medium.com/flutter-community/executing-dart-in-the-background-with-flutter-plugins-and-geofencing-2b3e40a1a124
- **OSRM Setup:** https://github.com/Project-OSRM/osrm-backend/wiki

### Herramientas
- **PostGIS Viewer:** QGIS (https://qgis.org/)
- **API Testing:** Postman (https://www.postman.com/)
- **DB Admin:** pgAdmin (https://www.pgadmin.org/)
- **Monitoring:** Grafana (https://grafana.com/)

---

## ✅ Checklist Final

### Antes de Desplegar a Producción

#### Seguridad:
- [ ] HTTPS configurado con certificado válido
- [ ] Credenciales en variables de entorno (no en código)
- [ ] Rate limiting activado
- [ ] Firebase rules configuradas
- [ ] SQL injection protection verificado
- [ ] CORS configurado correctamente

#### Performance:
- [ ] Índices de DB creados
- [ ] Connection pooling configurado
- [ ] Caching implementado donde aplica
- [ ] Queries optimizadas (< 100ms)
- [ ] Images/assets optimizados

#### Monitoreo:
- [ ] Logging configurado
- [ ] Error tracking (Sentry/similar)
- [ ] Uptime monitoring
- [ ] Alertas configuradas
- [ ] Backup automático funcionando

#### Legal:
- [ ] Política de privacidad publicada
- [ ] Términos de servicio publicados
- [ ] Consentimiento de usuario implementado
- [ ] GDPR compliance verificado (si aplica)

#### Testing:
- [ ] Tests unitarios pasando
- [ ] Tests de integración pasando
- [ ] Probado en múltiples dispositivos
- [ ] Probado en diferentes condiciones de red
- [ ] Load testing realizado

#### Documentación:
- [ ] README actualizado
- [ ] API documentation completa
- [ ] Runbook para operaciones
- [ ] Guía de troubleshooting
- [ ] Changelog actualizado

---

## 📱 Frontend (Mobile) - Estado actual y comandos

### Estructura implementada (Flutter)

```
lib/
├── main.dart                            # Arranque de app, `LocationTrackerApp`
├── config/
│   └── constants.dart                   # `Constants.apiBaseUrl`
├── firebase_options.dart                # Config firebase (generado por flutterfire)
├── models/
│   └── location_point.dart              # Modelo `LocationPoint`
├── services/
│   ├── api_service.dart                 # Cliente HTTP (registro usuario + ubicaciones)
│   ├── auth_service.dart                # Wrapper FirebaseAuth (login/register/logout)
│   ├── identity_service.dart            # Exposición del usuario autenticado via Firebase
│   ├── location_service.dart            # Servicio ubicación (Geolocator + stream)
│   ├── foreground_service_manager.dart  # Inicializa flutter_foreground_task (notificación)
│   ├── location_sync_manager.dart       # Maneja reintentos/offline queue
│   └── pending_location_store.dart      # Persistencia de pendientes (SharedPreferences)
└── screens/
    ├── login_screen.dart                # Formulario de login/registro (Firebase Auth)
    └── map_screen.dart                  # Pantalla de mapa (flutter_map)
```

- **`lib/main.dart`**: Inicializa Firebase, escucha el estado de autenticación y redirige a `LoginScreen` o `MapScreen`.
- **`lib/screens/map_screen.dart`**: Mapa con `flutter_map`, visualiza la ruta con `PolylineLayer` y marcadores de inicio/fin. Botón principal para iniciar/detener tracking, atajo para recenter y botón de historial (consulta `/api/locations/history`) que pinta la ruta guardada, muestra distancia total y despliega un modal con la lista detallada de puntos (lat/lon/hora). Incluye menú para cerrar sesión.
- **`lib/screens/login_screen.dart`**: UI de inicio de sesión y registro usando Firebase Auth (email/contraseña).
- **`lib/services/auth_service.dart`**: Encapsula Firebase Auth (signIn/signUp/signOut) y expone `authStateChanges`.
- **`lib/services/identity_service.dart`**: Expone el usuario autenticado (`uid`, `email`, `getIdToken`) usando Firebase Auth.
- **`lib/services/location_service.dart`**: Encapsula permisos y stream de posiciones con `Geolocator`, mappea métricas (accuracy, speed, heading). Arranca/detiene el servicio foreground y expone `start()`, `stop()`, `getCurrentOnce()` y `stream` de `LocationPoint`.
- **`lib/services/foreground_service_manager.dart`**: Configura `flutter_foreground_task`, mantiene notificación persistente y muestra batería usando `battery_plus` para evitar que Android mate el proceso en background.
- **`lib/services/identity_service.dart`**: Genera/persiste un UID (UUID) y email sintético para registrar el usuario en el backend.
- **`lib/services/api_service.dart`**: Envía `POST /api/users`, `POST /api/locations` y expone `GET /api/locations/history`/`/distance`.
- **`lib/models/location_point.dart`**: Incluye lat/lon/timestamp y campos opcionales (`accuracy`, `altitude`, `speed`, `heading`), con `toJson`.
- **`lib/config/constants.dart`**: Calcula `apiBaseUrl` dinámico (`10.0.2.2` en Android, `localhost` en otras plataformas).
- **`lib/services/location_sync_manager.dart` + `pending_location_store.dart`**: Guardan ubicaciones pendientes en `SharedPreferences` y las reintentan cuando el backend vuelve a estar disponible.

> **Autenticación:** la app presenta un flujo de login/registro con Firebase Auth (email/contraseña). Tras autenticarse, se usan el `firebaseUid` real y el ID token para registrar al usuario y enviar las ubicaciones al backend.

### Dependencias móviles (pubspec.yaml)

Referencia directa desde `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  geolocator: ^11.0.0
  flutter_map: ^6.1.0
  latlong2: ^0.9.0
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  flutter_foreground_task: ^6.1.1
  battery_plus: ^5.0.2
  http: ^1.1.2
  shared_preferences: ^2.3.2
```

Nota: Aunque `firebase_*`, `flutter_foreground_task`, `battery_plus` y `http` están listadas para el roadmap, la implementación actual utiliza principalmente `geolocator`, `flutter_map` y `latlong2`.

### Comandos usados para ejecutar el frontend

- **Instalación y verificación**
  - `flutter doctor`  
  - `flutter pub get`
  - `flutterfire configure` (genera `lib/firebase_options.dart` y archivos nativos)
  - Copiar `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist` provistos por Firebase

> El repositorio contiene un `lib/firebase_options.dart` de ejemplo que lanza una excepción. Reemplázalo por el archivo generado automáticamente tras ejecutar `flutterfire configure`.

- **Dispositivos y emuladores**
  - `flutter devices`  
  - `flutter emulators`  
  - `emulator -avd flutter_emulator &`  
  - `adb wait-for-device`

- **Ejecución y desarrollo**
  - `flutter run`  
  - En sesión interactiva: usar `r` (hot reload) y `R` (hot restart)

- **Builds**
  - `flutter build apk --release`  
  - Salida: `build/app/outputs/flutter-apk/app-release.apk`

### Notas de permisos Android (recordatorio)

Para tracking en background y mapas, recuerda configurar permisos en `android/app/src/main/AndroidManifest.xml` (ubicación precisa, foreground service, internet, etc.). La guía detallada ya está en este documento en la sección de setup de Android.

- Se activa un servicio `flutter_foreground_task` cuando el tracking está en marcha para evitar que el sistema finalice la app en segundo plano. La notificación muestra el nivel de batería (requerido por políticas Android 13+).

---

## 🎉 Conclusión

Este documento representa el blueprint completo para tu proyecto de tracking de ubicación. Con este plan, tienes:

✅ Stack tecnológico definido y justificado
✅ Arquitectura clara y escalable
✅ Plan de desarrollo semana a semana
✅ Código de referencia para empezar
✅ Guías de setup y despliegue
✅ Roadmap a futuro

**Siguiente paso:** Comenzar con el setup del servidor (Persona 1) y proyecto Flutter (Persona 2).

¡Mucho éxito con el proyecto! 🚀

---

**Versión:** 1.0
**Fecha:** Octubre 2025
**Autores:** [Tu equipo]
**Licencia:** [A definir]

---

## 🤖 Configuración de Emulador Android desde Terminal

Esta sección documenta cómo crear y ejecutar un emulador Android usando únicamente la línea de comandos, útil cuando no tienes Android Studio instalado o prefieres automatizar el proceso.

### 1. Verificar las herramientas de Android SDK disponibles

Primero, asegúrate de que las herramientas de línea de comandos del Android SDK estén correctamente instaladas y configuradas:

```bash
# Configurar variables de entorno
export ANDROID_HOME=~/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator

# Verificar que sdkmanager está disponible
which sdkmanager
# Salida esperada: /home/usuario/Android/Sdk/cmdline-tools/latest/bin/sdkmanager

# Verificar que avdmanager está disponible
which avdmanager
# Salida esperada: /home/usuario/Android/Sdk/cmdline-tools/latest/bin/avdmanager
```

### 2. Listar imágenes del sistema disponibles

Puedes verificar qué imágenes del sistema (system images) ya tienes instaladas:

```bash
# Ver imágenes instaladas localmente
ls ~/Android/Sdk/system-images/

# Ejemplo de salida:
# android-33  android-34  android-35  android-36  android-36.1

# Ver detalles de una imagen específica
ls ~/Android/Sdk/system-images/android-34/
# Salida: google_apis_playstore

# Verificar que la imagen está completa
find ~/Android/Sdk/system-images/android-34 -name "system.img"
# Si encuentra archivos .img, la imagen está lista para usar
```

**Nota:** Si necesitas descargar nuevas imágenes del sistema, usa:

```bash
# Listar todas las imágenes disponibles para descargar
sdkmanager --list | grep "system-images"

# Instalar una imagen específica (ejemplo: Android 34 con Play Store)
sdkmanager "system-images;android-34;google_apis_playstore;x86_64"
```

### 3. Descargar una imagen del sistema Android

Las imágenes del sistema ya instaladas en tu máquina incluyen:
- **Android 34** (API 34) - Recomendado para desarrollo
- **Android 35, 36, 36.1** - Versiones más recientes

Si ya tienes imágenes instaladas (como en el ejemplo anterior), puedes saltarte este paso. De lo contrario:

```bash
# Ejemplo: Instalar Android 34 con Google Play Store
sdkmanager "system-images;android-34;google_apis_playstore;x86_64"

# Aceptar licencias si es necesario
sdkmanager --licenses
```

### 4. Crear el emulador AVD (Android Virtual Device)

Usa `avdmanager` para crear un nuevo dispositivo virtual:

```bash
# Crear emulador con Android 34, tipo Pixel 6
echo "no" | ~/Android/Sdk/cmdline-tools/latest/bin/avdmanager create avd \
  -n flutter_emulator \
  -k "system-images;android-34;google_apis_playstore;x86_64" \
  -d "pixel_6"

# Salida esperada:
# Loading local repository...
# Auto-selecting single ABI x86_64
# AVD 'flutter_emulator' created successfully
```

**Parámetros explicados:**
- `-n flutter_emulator` - Nombre del emulador
- `-k "system-images;..."` - Path de la imagen del sistema a usar
- `-d "pixel_6"` - Tipo de dispositivo (también puede ser: pixel_5, pixel_7, nexus_5x, etc.)

**Verificar que se creó:**

```bash
# Listar emuladores disponibles
~/Android/Sdk/cmdline-tools/latest/bin/avdmanager list avd

# O con Flutter
flutter emulators
# Salida esperada: flutter_emulator
```

### 5. Iniciar el emulador

Existen dos formas de iniciar el emulador:

#### Opción A: Modo interactivo (con ventana)

```bash
# Iniciar el emulador
~/Android/Sdk/emulator/emulator -avd flutter_emulator

# Opciones útiles:
# -no-snapshot-save    No guarda el estado al cerrar (más rápido)
# -no-audio            Desactiva el audio (reduce recursos)
# -gpu host            Usa GPU del host (mejor rendimiento)
```

#### Opción B: Modo background (sin bloquear terminal)

```bash
# Iniciar en segundo plano
~/Android/Sdk/emulator/emulator -avd flutter_emulator -no-snapshot-save -no-audio > /tmp/emulator.log 2>&1 &

# Esperar a que arranque (puede tomar 1-2 minutos)
sleep 30

# Verificar estado
~/Android/Sdk/platform-tools/adb devices

# Salida cuando está listo:
# List of devices attached
# emulator-5554    device    ← "device" significa listo para usar
```

**Estados del emulador:**
- `offline` - Iniciando, aún no está listo
- `device` - Listo para recibir comandos
- `unauthorized` - Requiere autorización en pantalla

### 6. Ejecutar la aplicación Flutter en el emulador

Una vez que el emulador muestra estado `device`:

```bash
# Opción 1: Ejecutar en el emulador detectado automáticamente
flutter run

# Opción 2: Especificar el emulador explícitamente
flutter run -d emulator-5554

# Opción 3: Compilar e instalar APK directamente
flutter build apk
adb install build/app/outputs/flutter-apk/app-debug.apk
```

**Salida esperada durante la compilación:**

```
Resolving dependencies...
Got dependencies!
Launching lib/main.dart on sdk gphone64 x86 64 in debug mode...
Running Gradle task 'assembleDebug'...                          360.2s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...        1.5s

Flutter run key commands:
r Hot reload.
R Hot restart.
d Detach.
q Quit.
```

### Comandos útiles durante desarrollo

```bash
# Hot reload (aplicar cambios sin reiniciar)
# Presiona 'r' en la terminal donde corre Flutter

# Hot restart (reiniciar la app)
# Presiona 'R' en la terminal

# Ver logs en tiempo real
adb logcat | grep flutter

# Tomar screenshot del emulador
adb exec-out screencap -p > screenshot.png

# Simular ubicación GPS (útil para testing)
adb emu geo fix -77.0428 -12.0464  # longitud latitud

# Limpiar datos de la app
adb shell pm clear com.example.flutter_application_1

# Desinstalar la app
adb uninstall com.example.flutter_application_1
```

### Troubleshooting común

#### Problema: "ANDROID_HOME not found"
```bash
# Solución: Agregar a ~/.bashrc o ~/.zshrc
export ANDROID_HOME=~/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator

# Recargar configuración
source ~/.bashrc  # o source ~/.zshrc
```

#### Problema: El emulador no inicia o se queda "offline"
```bash
# Verificar que KVM está habilitado (Linux)
kvm-ok
# Si no está instalado: sudo apt install cpu-checker

# Dar permisos KVM
sudo usermod -aG kvm $USER
# Cerrar sesión y volver a entrar

# Reintentar con más tiempo de espera
sleep 60 && adb devices
```

#### Problema: "No space left on device"
```bash
# Eliminar emuladores viejos
avdmanager delete avd -n nombre_viejo

# Limpiar cachés de Android SDK
rm -rf ~/.android/avd/*.avd/cache/*

# Ver uso de espacio
du -sh ~/.android/avd/*
```

#### Problema: Gradle build muy lento
```bash
# Agregar a android/gradle.properties
org.gradle.jvmargs=-Xmx4096m
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.caching=true

# Limpiar caché de Gradle
cd android && ./gradlew clean
```

### Recomendaciones finales

#### Para desarrollo diario

1. **Mantén el emulador corriendo** - No lo cierres entre sesiones de desarrollo, ahorra tiempo de inicio
2. **Usa hot reload** - Presiona `r` para ver cambios instantáneamente sin recompilar
3. **Crea snapshots** - Guarda estados del emulador para inicio rápido:
   ```bash
   # Al cerrar el emulador, guarda estado
   emulator -avd flutter_emulator -snapshot-save my_snapshot

   # Restaurar snapshot al iniciar
   emulator -avd flutter_emulator -snapshot-load my_snapshot
   ```

#### Optimización de rendimiento

```bash
# Emulador más rápido con configuración optimizada
emulator -avd flutter_emulator \
  -no-snapshot-save \
  -no-audio \
  -gpu host \
  -memory 4096 \
  -cores 4 \
  -wipe-data  # Solo la primera vez
```

#### Para testing de ubicación

```bash
# Script para simular movimiento (crear archivo simulate_route.sh)
#!/bin/bash
# Simula ruta Lima, Perú
coords=(
  "-77.0428 -12.0464"
  "-77.0435 -12.0470"
  "-77.0442 -12.0476"
  "-77.0449 -12.0482"
)

for coord in "${coords[@]}"; do
  adb emu geo fix $coord
  echo "Ubicación establecida: $coord"
  sleep 300  # Esperar 5 minutos entre puntos
done
```

#### Automatización con script

Crea un archivo `start_dev.sh` para automatizar todo:

```bash
#!/bin/bash
# start_dev.sh - Inicia entorno de desarrollo completo

echo "🚀 Iniciando entorno de desarrollo..."

# 1. Iniciar emulador en background
echo "📱 Iniciando emulador Android..."
~/Android/Sdk/emulator/emulator -avd flutter_emulator -no-snapshot-save -no-audio &
EMULATOR_PID=$!

# 2. Esperar a que esté listo
echo "⏳ Esperando a que el emulador arranque..."
adb wait-for-device
sleep 10  # Espera adicional para que cargue completamente

# 3. Verificar estado
echo "✅ Emulador listo:"
adb devices

# 4. Ejecutar Flutter
echo "🔥 Ejecutando Flutter app..."
flutter run -d emulator-5554

# Cleanup al salir
trap "kill $EMULATOR_PID" EXIT
```

Hacer ejecutable:
```bash
chmod +x start_dev.sh
./start_dev.sh
```

#### Para producción / testing

```bash
# Compilar APK de release
flutter build apk --release

# APK estará en:
# build/app/outputs/flutter-apk/app-release.apk

# Instalar en dispositivo físico
adb install build/app/outputs/flutter-apk/app-release.apk

# O generar App Bundle para Play Store
flutter build appbundle --release
# Archivo en: build/app/outputs/bundle/release/app-release.aab
```

---

### Resumen de comandos esenciales

```bash
# Setup inicial (solo una vez)
export ANDROID_HOME=~/Android/Sdk
avdmanager create avd -n flutter_emulator -k "system-images;android-34;google_apis_playstore;x86_64" -d pixel_6

# Desarrollo diario
emulator -avd flutter_emulator &
adb wait-for-device
flutter run

# Comandos útiles
flutter devices              # Ver dispositivos disponibles
flutter emulators            # Ver emuladores disponibles
adb devices                  # Ver estado de dispositivos conectados
adb logcat | grep flutter    # Ver logs de Flutter
```

---

**¡Con esto tienes todo listo para desarrollar tu app de tracking de ubicación!** 🎉
