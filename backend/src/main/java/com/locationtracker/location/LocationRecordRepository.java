package com.locationtracker.location;

import com.locationtracker.user.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface LocationRecordRepository extends JpaRepository<LocationRecord, Long> {

    List<LocationRecord> findByUserAndTimestampBetweenOrderByTimestampAsc(User user,
                                                                          OffsetDateTime start,
                                                                          OffsetDateTime end);

    @Query(value = """
            WITH ordered AS (
                SELECT geom,
                       LAG(geom) OVER (ORDER BY "timestamp") AS prev_geom
                FROM locations
                WHERE user_id = :userId
                  AND "timestamp" >= :start
                  AND "timestamp" < :end
            )
            SELECT COALESCE(SUM(ST_Distance(geom, prev_geom)), 0)
            FROM ordered
            WHERE prev_geom IS NOT NULL
            """, nativeQuery = true)
    double calculateDistanceMeters(@Param("userId") UUID userId,
                                   @Param("start") OffsetDateTime start,
                                   @Param("end") OffsetDateTime end);
}
