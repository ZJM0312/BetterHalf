package com.betterhalf.api.config;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.config.MeterFilter;
import org.springframework.boot.actuate.autoconfigure.metrics.MeterRegistryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Observability configuration for metrics and tracing.
 */
@Configuration
public class ObservabilityConfig {
    
    @Bean
    public MeterRegistryCustomizer<MeterRegistry> metricsCommonTags() {
        return registry -> registry.config()
            .meterFilter(MeterFilter.denyNameStartsWith("jvm"))
            .commonTags("application", "betterhalf-api", "environment", "production");
    }
}
