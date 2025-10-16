-- Smoke test que inserta un usuario y una ubicación y muestra el último registro creado.
-- Ejecutar con:
--   cat database/smoke_test.sql | docker compose exec -T postgres psql -U locationapp -d location_tracker

INSERT INTO users (email, firebase_uid)
VALUES ('smoke@example.com', 'smoke-uid')
ON CONFLICT (firebase_uid) DO UPDATE SET email = EXCLUDED.email;

INSERT INTO locations (
  user_id,
  geom,
  timestamp,
  accuracy,
  battery_level,
  speed,
  heading
)
SELECT
  id,
  ST_SetSRID(ST_MakePoint(-77.0428, -12.0464), 4326),
  NOW(),
  12.3,
  88,
  5.4,
  180
FROM users
WHERE firebase_uid = 'smoke-uid'
RETURNING id;

SELECT
  u.email,
  u.firebase_uid,
  l.id AS location_id,
  ST_Y(l.geom::geometry) AS latitude,
  ST_X(l.geom::geometry) AS longitude,
  l.timestamp,
  l.accuracy,
  l.battery_level
FROM users u
JOIN locations l ON l.user_id = u.id
WHERE u.firebase_uid = 'smoke-uid'
ORDER BY l.id DESC
LIMIT 1;
