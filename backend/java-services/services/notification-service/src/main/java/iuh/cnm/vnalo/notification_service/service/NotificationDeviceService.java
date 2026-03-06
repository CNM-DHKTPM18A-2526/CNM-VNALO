package iuh.cnm.vnalo.notification_service.service;

import iuh.cnm.vnalo.notification_service.model.dto.RegisterDeviceRequest;
import iuh.cnm.vnalo.notification_service.model.entity.NotificationDevice;
import iuh.cnm.vnalo.notification_service.repository.NotificationDeviceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class NotificationDeviceService {

    private final NotificationDeviceRepository deviceRepo;

    public NotificationDevice register(UUID userId, RegisterDeviceRequest req) {
        var existing = deviceRepo.findByUserIdAndDeviceId(userId, req.getDeviceId());
        var device = existing.orElseGet(NotificationDevice::new);

        device.setUserId(userId);
        device.setDeviceId(req.getDeviceId());
        device.setPlatform(req.getPlatform());
        device.setFcmToken(req.getFcmToken());
        device.setIsActive(true);

        return deviceRepo.save(device);
    }
}
