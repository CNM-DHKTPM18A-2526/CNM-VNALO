package iuh.cnm.vnalo.messagingservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.cassandra.config.AbstractCassandraConfiguration;
import org.springframework.data.cassandra.config.SchemaAction;
import org.springframework.data.cassandra.repository.config.EnableCassandraRepositories;

/**
 * Cassandra configuration for the Message domain.
 * Messages are stored in Cassandra for high write throughput and efficient
 * partition-based reads (by conversation_id).
 */
@Configuration
@EnableCassandraRepositories(basePackages = "iuh.cnm.vnalo.messagingservice.repository.message")
public class CassandraConfig extends AbstractCassandraConfiguration {

    @Value("${spring.cassandra.contact-points:localhost}")
    private String contactPoints;

    @Value("${spring.cassandra.port:9042}")
    private int port;

    @Value("${spring.cassandra.keyspace-name:vnalo_messaging}")
    private String keyspaceName;

    @Value("${spring.cassandra.local-datacenter:datacenter1}")
    private String localDatacenter;

    @Value("${spring.cassandra.schema-action:CREATE_IF_NOT_EXISTS}")
    private String schemaAction;

    @Override
    protected String getKeyspaceName() {
        return keyspaceName;
    }

    @Override
    protected String getContactPoints() {
        return contactPoints;
    }

    @Override
    protected int getPort() {
        return port;
    }

    @Override
    protected String getLocalDataCenter() {
        return localDatacenter;
    }

    @Override
    public SchemaAction getSchemaAction() {
        return SchemaAction.valueOf(schemaAction);
    }

    @Override
    public String[] getEntityBasePackages() {
        return new String[]{"iuh.cnm.vnalo.messagingservice.model.entity.message"};
    }
}
