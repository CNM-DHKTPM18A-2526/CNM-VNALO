package iuh.cnm.vnalo.core_service.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

@Component
@ConfigurationProperties(prefix = "face.auth")
@Getter
@Setter
public class FaceAuthProperties {

    private boolean enabled = false;

    private String modelPath = "classpath:models";

    private BigDecimal verificationThreshold = new BigDecimal("0.65");

    private BigDecimal livenessThreshold = new BigDecimal("0.7");

    private boolean enrollmentEnabled = true;

    private boolean verificationEnabled = true;

    private String encryptionKey;
}
