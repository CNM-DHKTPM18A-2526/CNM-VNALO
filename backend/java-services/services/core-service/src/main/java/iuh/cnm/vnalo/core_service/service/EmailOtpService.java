package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.config.OtpConfig;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import jakarta.mail.MessagingException;
import java.io.UnsupportedEncodingException;
import java.nio.charset.StandardCharsets;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailOtpService {

    private final JavaMailSender mailSender;
    private final OtpConfig otpConfig;

    @Value("${spring.mail.username:no-reply@vnalo.local}")
    private String fromAddress;

    @Value("${otp.email-from-name:VNALO Security}")
    private String fromName;

    public void ensureDeliveryEnabled() {
        if (!otpConfig.isEmailEnabled()) {
            throw new ApiException(ErrorCode.AUTH_OTP_DELIVERY_FAILED);
        }
    }

    public void sendOtp(String email, String otp, OtpPurpose purpose) {
        try {
            sendOtpNow(email, otp, purpose);
        } catch (MailException | MessagingException | UnsupportedEncodingException ex) {
            log.error("Failed to send OTP email to {}", maskEmail(email), ex);
        }
    }

    private void sendOtpNow(String email, String otp, OtpPurpose purpose)
            throws MessagingException, UnsupportedEncodingException {
        ensureDeliveryEnabled();

        final OtpEmailContent content = buildContent(purpose);
        final var mimeMessage = mailSender.createMimeMessage();
        final var helper = new MimeMessageHelper(mimeMessage, true, StandardCharsets.UTF_8.name());
        helper.setFrom(fromAddress, fromName);
        helper.setTo(email);
        helper.setSubject(content.subject());
        helper.setText(buildPlainText(otp, content), buildHtmlBody(otp, content));
        mailSender.send(mimeMessage);
        log.info("OTP email accepted by mail transport for {}", maskEmail(email));
    }

    private OtpEmailContent buildContent(OtpPurpose purpose) {
        return switch (purpose) {
            case REGISTER -> new OtpEmailContent(
                "Mã xác thực đăng ký VNALO",
                "Xác thực email để hoàn tất đăng ký",
                "Sử dụng mã OTP bên dưới để tiếp tục tạo tài khoản VNALO của bạn.",
                "hoàn tất đăng ký"
            );
            case RESET_PASSWORD -> new OtpEmailContent(
                "Mã đặt lại mật khẩu VNALO",
                "Xác thực yêu cầu đặt lại mật khẩu",
                "Sử dụng mã OTP bên dưới để tiếp tục đặt lại mật khẩu tài khoản.",
                "đặt lại mật khẩu"
            );
            case LOGIN -> new OtpEmailContent(
                "Mã đăng nhập VNALO",
                "Xác thực đăng nhập tài khoản",
                "Sử dụng mã OTP bên dưới để xác nhận đăng nhập an toàn.",
                "xác nhận đăng nhập"
            );
            case CHANGE_EMAIL -> new OtpEmailContent(
                "Mã xác thực thay đổi email VNALO",
                "Xác thực thay đổi địa chỉ email",
                "Sử dụng mã OTP bên dưới để xác nhận thay đổi email tài khoản.",
                "xác nhận thay đổi email"
            );
            case CHANGE_PHONE -> new OtpEmailContent(
                "Mã xác thực thay đổi số điện thoại VNALO",
                "Xác thực thay đổi số điện thoại",
                "Sử dụng mã OTP bên dưới để xác nhận thay đổi số điện thoại tài khoản.",
                "xác nhận thay đổi số điện thoại"
            );
        };
    }

    private String buildPlainText(String otp, OtpEmailContent content) {
        return content.title() + "\n\n"
            + content.lead() + "\n"
            + "Mã OTP: " + otp + "\n\n"
            + "Mã có hiệu lực trong " + otpConfig.getExpirationMinutes() + " phút.\n"
            + "Vui lòng không chia sẻ mã này cho bất kỳ ai, kể cả người tự xưng là nhân viên VNALO.\n\n"
            + "Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email này.\n\n"
            + "VNALO Security";
    }

    private String buildHtmlBody(String otp, OtpEmailContent content) {
        return """
            <!doctype html>
            <html lang="vi">
              <body style="margin:0;padding:0;background:#f4f7fb;font-family:Arial,'Helvetica Neue',sans-serif;color:#0f172a;">
                <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
                  %s
                </div>
                <table role="presentation" width="100%%" cellspacing="0" cellpadding="0" style="background:#f4f7fb;padding:24px 12px;">
                  <tr>
                    <td align="center">
                      <table role="presentation" width="100%%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 12px 40px rgba(15,23,42,0.08);">
                        <tr>
                          <td style="padding:28px 32px;background:linear-gradient(135deg,#0068ff 0%%,#00a2ed 100%%);color:#ffffff;">
                            <div style="font-size:13px;letter-spacing:0.12em;text-transform:uppercase;opacity:0.88;">VNALO Security</div>
                            <h1 style="margin:10px 0 0;font-size:24px;line-height:1.35;">%s</h1>
                          </td>
                        </tr>
                        <tr>
                          <td style="padding:28px 32px 20px;">
                            <p style="margin:0 0 12px;font-size:16px;line-height:1.6;color:#334155;">%s</p>
                            <div style="margin:20px 0;padding:18px 20px;border-radius:16px;background:#eff6ff;border:1px solid #bfdbfe;">
                              <div style="font-size:12px;letter-spacing:0.08em;text-transform:uppercase;color:#2563eb;margin-bottom:8px;">Mã OTP</div>
                              <div style="font-size:34px;font-weight:700;letter-spacing:0.22em;color:#0f172a;">%s</div>
                            </div>
                            <p style="margin:0 0 14px;font-size:14px;line-height:1.7;color:#475569;">
                              Mã có hiệu lực trong <strong>%d phút</strong>. Vui lòng nhập mã này để %s.
                            </p>
                            <div style="padding:14px 16px;border-radius:14px;background:#fff7ed;border:1px solid #fdba74;color:#9a3412;font-size:13px;line-height:1.6;">
                              Không chia sẻ OTP cho bất kỳ ai, kể cả người tự xưng là nhân viên hỗ trợ của VNALO.
                            </div>
                          </td>
                        </tr>
                        <tr>
                          <td style="padding:0 32px 28px;color:#64748b;font-size:12px;line-height:1.7;">
                            Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email này.
                            <br/>
                            © VNALO. Bảo mật tài khoản là ưu tiên hàng đầu.
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                </table>
              </body>
            </html>
            """.formatted(
            content.lead(),
            content.title(),
            content.lead(),
            otp,
            otpConfig.getExpirationMinutes(),
            content.actionLabel()
        );
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

    private record OtpEmailContent(
        String subject,
        String title,
        String lead,
        String actionLabel
    ) {}
}
