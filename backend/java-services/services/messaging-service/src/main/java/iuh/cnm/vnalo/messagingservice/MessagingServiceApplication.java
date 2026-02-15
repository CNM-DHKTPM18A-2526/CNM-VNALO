package iuh.cnm.vnalo.messagingservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
@EntityScan(basePackages = {
        "iuh.cnm.vnalo.messagingservice.model.entity.conversation",
        "iuh.cnm.vnalo.messagingservice.model.entity.call",
        "iuh.cnm.vnalo.messagingservice.model.entity.notification",
        "iuh.cnm.vnalo.messagingservice.model.entity"
})
@EnableJpaRepositories(basePackages = {
        "iuh.cnm.vnalo.messagingservice.repository.conversation",
        "iuh.cnm.vnalo.messagingservice.repository.call",
        "iuh.cnm.vnalo.messagingservice.repository.notification",
        "iuh.cnm.vnalo.messagingservice.repository.message"
},
excludeFilters = @org.springframework.context.annotation.ComponentScan.Filter(
        type = org.springframework.context.annotation.FilterType.ASSIGNABLE_TYPE,
        classes = iuh.cnm.vnalo.messagingservice.repository.message.MessageRepository.class
))
public class MessagingServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(MessagingServiceApplication.class, args);
    }

}
