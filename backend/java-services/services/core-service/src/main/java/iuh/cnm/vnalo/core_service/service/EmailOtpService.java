package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailOtpService {

    private final JavaMailSender mailSender;

    @Value("${otp.email.enabled:true}")
    private boolean emailOtpEnabled;

    @Value("${spring.mail.username:no-reply@vnalo.local}")
    private String fromAddress;

    public void sendOtp(String email, String otp, OtpPurpose purpose) {
        if (!emailOtpEnabled) {
            throw new ApiException(ErrorCode.AUTH_OTP_DELIVERY_FAILED);
        }

        final SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(fromAddress);
        message.setTo(email);
        message.setSubject("VNALO OTP - " + purpose.name());
        message.setText(buildBody(otp, purpose));

        try {
            mailSender.send(message);
        } catch (MailException ex) {
            log.error("Failed to send OTP email to {}", maskEmail(email), ex);
            throw new ApiException(ErrorCode.AUTH_OTP_DELIVERY_FAILED);
        }
    }

    private String buildBody(String otp, OtpPurpose purpose) {
        return "Ma OTP cua ban la: " + otp + "\n"
                + "Muc dich: " + purpose.name() + "\n"
                + "Ma co hieu luc trong 5 phut. Vui long khong chia se OTP cho bat ky ai.";
    }

    private String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return "***";
        }
        final int at = email.indexOf('@');
        if (at <= 1) {
            return "***";
        }
        return email.charAt(0) + "***" + email.substring(at);
    }
}
