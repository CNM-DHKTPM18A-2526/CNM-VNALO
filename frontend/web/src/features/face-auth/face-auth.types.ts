export type FaceEnrollmentResponse = {
  success: boolean
  enrolledAt: string | null
  livenessScore: number | null
  version: number | null
  errorCode: string | null
  message: string | null
}

export type FaceVerifyResponse = {
  verified: boolean
  confidence: number | null
  threshold: number | null
  decision: string | null
  inferenceTimeMs: number | null
  errorCode: string | null
  message: string | null
}

export type FaceStatusResponse = {
  enrolled: boolean
  enrolledAt: string | null
  version: number | null
  errorCode: string | null
  message: string | null
}

export type FaceLivenessResult = {
  isLive: boolean
  score: number
  threshold: number
  pass: boolean
}

export type FaceHealthResponse = {
  enabled: boolean
  modelReady: boolean
  timestamp: string
}

export type FaceError = {
  errorCode: string
  message: string
}

export type FaceEnrollmentState = 'idle' | 'capturing' | 'processing' | 'success' | 'error'
export type FaceVerificationState = 'idle' | 'verifying' | 'verified' | 'rejected' | 'error'
