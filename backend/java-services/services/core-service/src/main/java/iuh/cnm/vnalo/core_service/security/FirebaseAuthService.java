package iuh.cnm.vnalo.core_service.security;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class FirebaseAuthService {
    public String verifyIdToken(String idToken) {
        try {
            // verify token with Firebase servers
            FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(idToken);

            // get phone number from token
            String phoneNumber = decodedToken.getClaims()
                    .get("phone_number").toString();

            log.info("Firebase token verified for phone: {}",
                    maskPhone(phoneNumber));

            return phoneNumber;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    /**
     * Mask phone number for logging
     * VD: +84901234567 -> +84****4567
     */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 8) return "****";
        return phone.substring(0, 4) + "****" +
                phone.substring(phone.length() - 4);
    }
}
