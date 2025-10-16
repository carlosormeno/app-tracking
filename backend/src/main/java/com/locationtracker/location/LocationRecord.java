package com.locationtracker.location;

import java.time.OffsetDateTime;

import org.hibernate.annotations.JdbcTypeCode;
import org.locationtech.jts.geom.Point;

import com.locationtracker.user.User;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.type.SqlTypes;

@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name = "locations")
public class LocationRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @JdbcTypeCode(SqlTypes.GEOMETRY)
    @Column(columnDefinition = "geography(Point,4326)", nullable = false)
    private Point geom;

    @Column(nullable = false)
    private OffsetDateTime timestamp;

    @Column
    private Double accuracy;

    @Column
    private Double altitude;

    @Column
    private Double speed;

    @Column
    private Double heading;

    @Column(name = "battery_level")
    private Integer batteryLevel;

    @Column(name = "activity_type")
    private String activityType;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    @PrePersist
    public void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }
}
