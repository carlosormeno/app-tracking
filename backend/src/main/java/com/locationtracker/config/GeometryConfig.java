package com.locationtracker.config;

import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class GeometryConfig {

    @Bean
    public GeometryFactory geometryFactory() {
        PrecisionModel precisionModel = new PrecisionModel(PrecisionModel.FLOATING);
        int srid = 4326; // WGS84
        return new GeometryFactory(precisionModel, srid);
    }
}
