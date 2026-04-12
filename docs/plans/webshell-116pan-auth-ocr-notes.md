# WebShell 116pan Auth And OCR Notes

## 2026-04-11 Probe Result
- 116pan supports lightweight captcha retry for the current login session.
- Probe method:
  - fetch `/login` once and keep the returned cookies and CSRF token
  - fetch `/captcha/20` repeatedly with the same cookie jar
  - submit the latest captcha with a fake account
- Result:
  - submitting a correctly read latest captcha returned account/password failure
  - the same response had no `captchaError`
  - therefore the retry path should prefer `refresh captcha -> OCR -> login`
  - full `login page/cookie -> captcha -> OCR -> login` remains the fallback strategy for providers that do not support lightweight captcha refresh

## Rule Contract
- `AuthPolicy.captchaRetryPolicy.mode = refreshCaptcha` means the resolver keeps the current auth runtime state and re-executes from the configured captcha refresh output.
- `AuthPolicy.captchaRetryPolicy.mode = fullWorkflow` or missing policy means each retry re-runs the complete auth workflow.
- Default retry budget:
  - `refreshCaptcha`: 50 attempts because only the captcha image and login POST are repeated
  - `fullWorkflow`: 10 attempts because the login page and cookie state are recreated each round
- New captcha providers should be probed before promotion:
  - if same-session captcha refresh works, use `refreshCaptcha`
  - if the provider binds captcha to a new login page or cookie, use `fullWorkflow`

## Offline OCR Sample Result
- Vision OCR can solve some 116pan samples directly, but it still produces high-confidence wrong answers for noisy samples.
- Low-risk improvement:
  - keep the original image as the first truth candidate
  - only fall back to scaled, grayscale, and sharpened variants when the original result has no 4-character candidate
  - normalize ASCII-like Unicode confusables before submission
- Current limitation:
  - preprocessing does not reliably fix wrong 4-character candidates
  - repeatedly hitting the real provider is not a valid way to tune OCR

## ML Escalation Gate
- Move to a dedicated ML plan if real E2E still repeatedly exhausts captcha retries after collecting debug captcha images.
- Required plan scope:
  - collect provider-scoped captcha samples through `WEBSHELL_CAPTCHA_DEBUG_DIR`
  - label samples with ground truth outside the live login loop
  - train/evaluate a captcha-specific detector/recognizer, likely YOLO-style segmentation plus character recognition or a compact CRNN
  - export to CoreML for local-only inference
  - keep provider credentials and captcha images out of source control
