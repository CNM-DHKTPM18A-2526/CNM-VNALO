import { useEffect, useRef, useState } from 'react';
import { verifyFace, getFaceHealth, faceLogin, lookupUserId, withTimeout } from '../face-auth.api';
import { useAuth } from '../../auth/useAuth';

type FaceLoginModalProps = {
  onClose: () => void;
  onNotEnrolled: () => void;
  onSuccess: () => void;
};

type LoginStep =
  | 'identifier'
  | 'camera'
  | 'verifying'
  | 'error'
  | 'service-unavailable';

const WEB_DEVICE_STORAGE_KEY = 'vnalo.web.deviceId';

function resolveWebDeviceId(): string {
  const stored = window.localStorage.getItem(WEB_DEVICE_STORAGE_KEY);
  if (stored && stored.trim().length > 0) return stored;
  const generated =
    typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
      ? `web-${crypto.randomUUID()}`
      : `web-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  window.localStorage.setItem(WEB_DEVICE_STORAGE_KEY, generated);
  return generated;
}

function normalizeIdentifier(id: string): string {
  const t = id.trim();
  if (!t) return t;
  const compact = t.replace(/[\s-]/g, '');
  if (/^0\d{9}$/.test(compact)) return `+84${compact.slice(1)}`;
  return compact;
}

function getCameraErrorMessage(err: unknown): string {
  if (err instanceof Error) {
    if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
      return 'Bạn chưa cấp quyền truy cập camera. Vui lòng cho phép trong cài đặt trình duyệt.';
    }
    if (err.name === 'NotFoundError' || err.name === 'DevicesNotFoundError') {
      return 'Không tìm thấy camera. Vui lòng kết nối camera và thử lại.';
    }
    if (err.name === 'NotReadableError' || err.name === 'TrackStartError') {
      return 'Camera đang được sử dụng bởi ứng dụng khác. Vui lòng đóng ứng dụng khác và thử lại.';
    }
    return err.message;
  }
  return 'Không thể truy cập camera.';
}

async function captureFrame(video: HTMLVideoElement): Promise<Blob> {
  const canvas = document.createElement('canvas');
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(video, 0, 0);
  return new Promise((resolve, reject) => {
    canvas.toBlob(blob => {
      if (blob) resolve(blob);
      else reject(new Error('Không thể chụp ảnh từ camera.'));
    }, 'image/jpeg', 0.92);
  });
}


export function FaceLoginModal({ onClose, onNotEnrolled, onSuccess }: FaceLoginModalProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const { loginWithAccessToken } = useAuth();

  const [step, setStep] = useState<LoginStep>('identifier');
  const [identifier, setIdentifier] = useState('');
  const [identifierError, setIdentifierError] = useState<string | null>(null);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [serviceAvailable, setServiceAvailable] = useState<boolean | null>(null);

  async function checkServiceHealth() {
    try {
      const health = await getFaceHealth();
      setServiceAvailable(health.enabled && health.modelReady);
    } catch {
      setServiceAvailable(false);
    }
  }

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void checkServiceHealth();
    }, 0);

    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(t => t.stop());
      }
    };
  }, []);

  async function handleFindAccount() {
    setIdentifierError(null);
    const norm = normalizeIdentifier(identifier);
    if (!norm) {
      setIdentifierError('Vui lòng nhập số điện thoại hoặc email.');
      return;
    }
    if (serviceAvailable !== true) {
      if (serviceAvailable === false) {
        setStep('service-unavailable');
      }
      return;
    }
    setStep('camera');
    setTimeout(() => { void initCamera(); }, 100);
  }

  async function initCamera() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
    } catch (err) {
      setCameraError(getCameraErrorMessage(err));
    }
  }

  async function handleCapture() {
    if (!videoRef.current) return;
    setStep('verifying');

    try {
      const blob = await captureFrame(videoRef.current);
      
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(t => t.stop());
        streamRef.current = null;
      }
      
      const normId = normalizeIdentifier(identifier);

      const userId = await withTimeout(
        lookupUserId(normId),
        10_000,
        'Tra cứu tài khoản'
      );

      const verify = await withTimeout(
        verifyFace(blob, userId),
        20_000,
        'Xác thực khuôn mặt'
      );

      if (!verify.verified || !verify.verificationToken) {
        const isSpoofDetected = verify.decision === 'SPOOF_DETECTED';
        setErrorMsg(
          isSpoofDetected
            ? 'Phát hiện ảnh giả mạo. Vui lòng sử dụng khuôn mặt thật và thử lại.'
            : 'Khuôn mặt không khớp với tài khoản. Vui lòng thử lại hoặc đăng nhập bằng mật khẩu.'
        );
        setStep('error');
        return;
      }

      const deviceId = resolveWebDeviceId();
      const tokens = await withTimeout(
        faceLogin(verify.verificationToken, deviceId, 'VNALO Web', 'WEB'),
        10_000,
        'Đăng nhập'
      );
      await loginWithAccessToken(tokens.accessToken);
      onSuccess();
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Đăng nhập khuôn mặt thất bại.');
      setStep('error');
    }
  }

  function handleRetry() {
    setStep('identifier');
    setErrorMsg(null);
    setCameraError(null);
  }

  return (
    <div
      className="face-login-modal-overlay"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
      role="presentation"
    >
      <div className="face-login-modal" role="dialog" aria-modal="true" aria-labelledby="face-login-modal-title">
        <div className="face-login-modal-header">
          <span className="face-login-modal-title" id="face-login-modal-title">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ marginRight: 8, verticalAlign: 'middle' }} aria-hidden="true">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
              <circle cx="12" cy="7" r="4"></circle>
            </svg>
            Đăng nhập khuôn mặt
          </span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="auth-face-badge">thử nghiệm</span>
            <button className="face-login-modal-close" onClick={onClose} aria-label="Đóng">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </button>
          </div>
        </div>

        <div className="face-login-modal-body">
          {step === 'identifier' && (
            <div className="face-login-intro">
              <div className="face-login-icon-wrapper">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                  <circle cx="12" cy="7" r="4"></circle>
                </svg>
              </div>
              <p className="face-login-intro-text">
                Nhập số điện thoại hoặc email đã đăng ký, sau đó đưa khuôn mặt vào camera để đăng nhập nhanh.
              </p>
              <p className="face-login-intro-note">
                Bạn cần đã đăng ký khuôn mặt trong mục Cài đặt &gt; Khuôn mặt trước đó.
              </p>
              <div className="face-login-identifier-form">
                <input
                  type="text"
                  className="face-login-identifier-input"
                  placeholder="Số điện thoại hoặc email"
                  value={identifier}
                  onChange={(e) => { setIdentifier(e.target.value); setIdentifierError(null); }}
                  onKeyDown={(e) => { if (e.key === 'Enter') void handleFindAccount(); }}
                  autoFocus
                />
                {identifierError && (
                  <p className="face-login-field-error">{identifierError}</p>
                )}
              </div>
              <button
                type='button'
                className='btn btn-primary btn-block face-login-primary-btn'
                onClick={() => { void handleFindAccount() }}
                disabled={serviceAvailable === null}
              >
                {serviceAvailable === null ? 'Đang kiểm tra dịch vụ...' : 'Tiếp tục'}
              </button>
              <button className="face-login-secondary-link" onClick={onNotEnrolled}>
                Chưa đăng ký khuôn mặt?
              </button>
            </div>
          )}

          {step === 'camera' && (
            <div className="face-login-camera">
              <div className="face-login-camera-wrapper">
                <video ref={videoRef} className="face-login-video" playsInline muted autoPlay />
                <div className="face-login-camera-overlay">
                  <div className="face-login-camera-guide" />
                </div>
              </div>
              {cameraError ? (
                <p className="face-login-error-text">{cameraError}</p>
              ) : (
                <p className="face-login-camera-hint">
                  Đưa khuôn mặt vào khung, đảm bảo đủ ánh sáng
                </p>
              )}
              <button
                className="face-login-capture-btn"
                onClick={handleCapture}
                disabled={!!cameraError}
              >
                <span className="face-login-capture-ring" />
              </button>
              <button
                className="face-login-secondary-link"
                style={{ marginTop: 12 }}
                onClick={handleRetry}
              >
                ← Quay lại
              </button>
            </div>
          )}

          {step === 'verifying' && (
            <div className="face-login-verifying" role="status" aria-live="polite" aria-label="Đang xác thực khuôn mặt">
              <div className="face-login-spinner" aria-hidden="true" />
              <p className="face-login-verifying-text">Đang xác thực khuôn mặt...</p>
              <p className="face-login-verifying-sub">Vui lòng giữ yên khuôn mặt</p>
            </div>
          )}

          {step === 'error' && (
            <div className="face-login-error-state" role="alert">
              <div className="face-login-icon-wrapper face-login-icon-error">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden="true">
                  <circle cx="12" cy="12" r="10"></circle>
                  <line x1="15" y1="9" x2="9" y2="15"></line>
                  <line x1="9" y1="9" x2="15" y2="15"></line>
                </svg>
              </div>
              <p className="face-login-error-text">{errorMsg}</p>
              <button className="face-login-primary-btn" onClick={handleRetry}>
                Thử lại
              </button>
            </div>
          )}

          {step === 'service-unavailable' && (
            <div className="face-login-error-state">
              <div className="face-login-icon-wrapper face-login-icon-error">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <circle cx="12" cy="12" r="10"></circle>
                  <line x1="12" y1="8" x2="12" y2="12"></line>
                  <line x1="12" y1="16" x2="12.01" y2="16"></line>
                </svg>
              </div>
              <p className="face-login-error-text">
                Dịch vụ xác thực khuôn mặt hiện không khả dụng. Vui lòng thử lại sau hoặc đăng nhập bằng mật khẩu.
              </p>
              <button className="face-login-primary-btn" onClick={onClose}>
                Đóng
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
