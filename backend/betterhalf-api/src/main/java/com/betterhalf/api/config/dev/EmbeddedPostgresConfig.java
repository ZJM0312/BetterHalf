package com.betterhalf.api.config.dev;

import io.zonky.test.db.postgres.embedded.EmbeddedPostgres;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

import javax.sql.DataSource;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Zero-setup local database for the {@code dev} profile.
 * Starts a real PostgreSQL (not H2) so Flyway migrations run unchanged.
 * Data persists across restarts in {@code betterhalf.dev.data-dir}.
 */
@Configuration
@Profile("dev")
public class EmbeddedPostgresConfig {

    private static final Logger log = LoggerFactory.getLogger(EmbeddedPostgresConfig.class);

    @Bean(destroyMethod = "close")
    public EmbeddedPostgres embeddedPostgres(
        @Value("${betterhalf.dev.data-dir:${user.home}/.betterhalf/pgdata}") String dataDir,
        @Value("${betterhalf.dev.db-port:54329}") int port
    ) throws IOException {
        Path dir = Path.of(dataDir);
        Files.createDirectories(dir);
        boolean fresh = !Files.exists(dir.resolve("PG_VERSION"));
        log.info("Starting embedded PostgreSQL on port {} (data: {})", port, dir);
        return EmbeddedPostgres.builder()
            .setDataDirectory(dir)
            .setCleanDataDirectory(fresh)
            .setPort(port)
            .start();
    }

    @Bean
    public DataSource dataSource(EmbeddedPostgres pg) {
        return pg.getPostgresDatabase();
    }
}
