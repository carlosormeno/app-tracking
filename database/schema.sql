-- Schema base para la plataforma de tracking de ubicación
-- Ejecutar sobre PostgreSQL 16 con PostGIS 3.4

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- Necesario para gen_random_uuid()

-- Tabla de usuarios autenticados via Firebase
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  firebase_uid VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);

-- Tabla principal de ubicaciones capturadas
CREATE TABLE IF NOT EXISTS locations (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  geom GEOGRAPHY(Point, 4326) NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  accuracy DOUBLE PRECISION,
  altitude DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  heading DOUBLE PRECISION,
  battery_level SMALLINT,
  activity_type VARCHAR(50),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Índices recomendados
CREATE INDEX IF NOT EXISTS idx_locations_geom ON locations USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_locations_user_time ON locations(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_locations_activity ON locations(user_id, activity_type)
  WHERE activity_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_locations_recent ON locations(user_id, timestamp DESC)
  WHERE timestamp > NOW() - INTERVAL '30 days';

-- Trigger para mantener updated_at en users
CREATE OR REPLACE FUNCTION set_current_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_current_timestamp();
