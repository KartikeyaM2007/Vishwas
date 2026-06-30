# Flutter Android Handoff - 2026-06-24

## Assistant UX / Manual Verification / White Page Fix - 2026-06-25

- Added explicit failed-validation actions in `/citizen/assistant`:
  ```text
  Submit for Manual Verification
  Retake / Replace Proof
  Cancel Report
  ```
- Manual verification submit uses the existing `/mobile/report-submit` path but sends validation metadata:
  ```text
  validation_status=manual_review
  auto_submitted=false
  reward_eligible=false
  manual_review_reason=<validation reason>
  ```
- Backend now stores manual review metadata on mobile submissions:
  ```text
  validation_status
  validation_confidence
  validation_provider
  reward_eligible
  auto_submitted
  citizen_id
  ai_metadata.manual_review_reason
  ```
- Assistant success copy after manual submit:
  ```text
  Your report has been submitted for manual verification. You can track it in My Issues.
  ```
- Assistant conversation ordering was fixed:
  ```text
  user transcript
  GPS transition explanation
  location captured timeline item
  proof uploaded/captured timeline item
  proof verification message
  validation result card
  manual verification actions
  ```
- GPS flow now says why location is needed before capture, shows `Capturing Location`, and adds:
  ```text
  Location captured: Lat ..., Lng ..., Accuracy ... m
  ```
- GPS failure now shows:
  ```text
  Retry Location
  Open Settings
  Cancel
  ```
- Proof preview/GPS cards no longer appear above the conversation; they render after the chronological chat timeline.
- Assistant debug planner output is now behind a collapsible `Debug details` panel.
- Validation failure UI now uses citizen-friendly wording:
  ```text
  AI evidence validation is unavailable or confidence is too low. Submit for manual verification?
  ```
- My Issues white-page hardening:
  ```text
  /citizen/issue/:id fetches the complaint by id directly
  loading/error/not-found states always use Scaffold + AppBar
  issue load errors show a Retry button
  comments failures show Discussion unavailable instead of crashing the detail page
  ```
- Added mobile community route:
  ```text
  /citizen/community
  ```
- Home now has a Community Feed icon button. Community report cards open `/citizen/issue/:id`, where comments/replies work.
- Vapi was intentionally not added. Current APK remains native STT/TTS + Gemini planner.
- Verification:
  ```text
  python -m compileall E:\Vishwas\backend\Team-Try -> passed
  flutter analyze changed files -> No issues found
  backend /health -> healthy
  admin /review-queue -> count=1
  flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.18.165:8000 -> passed
  adb install -r app-debug.apk -> Success
  app launched, pid=7563
  logcat startup check -> no FlutterError/FATAL EXCEPTION/RenderFlex
  ```
- APK path:
  ```text
  E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
  ```
- Remaining manual tests: tap through My Issues detail cards on phone, post/reply to a real comment, and submit a failed proof for manual verification through the assistant.

## Citizen Comments And Status Label Polish - 2026-06-25

- Flutter mobile was updated after the earlier backend/web-only pass.
- Citizen issue detail route now has a shared `Discussion` section:
  ```text
  /citizen/issue/:id
  ```
- Citizens can:
  ```text
  load comments
  add top-level comments
  reply to comments
  see Admin / Verified Citizen / Citizen badges
  ```
- New Flutter model:
  ```text
  lib\features\issues\models\complaint_comment.dart
  ```
- Updated Flutter repository/provider wiring:
  ```text
  RemoteIssueRepository.fetchComments
  RemoteIssueRepository.addComment
  RemoteIssueRepository.replyToComment
  issueCommentsProvider
  ```
- Flutter issue cards now show comment count.
- Flutter titles and chips now use clean labels:
  ```text
  Water_leakage -> Water Leakage
  Manual_review -> Manual Review
  in_progress -> In Progress
  ```
- Flutter status enum and pills now support:
  ```text
  pending
  manual_review
  approved / verified / admin_approved
  needs_more_proof
  in_progress
  resolved
  rejected
  ```
- Status color mapping:
  ```text
  Pending = yellow
  Manual Review = orange
  Approved = blue/green
  Rejected = red
  Resolved = green
  Needs More Proof = purple/orange
  ```
- Targeted Flutter analysis passed:
  ```text
  flutter analyze changed mobile files -> No issues found
  ```
- Backend comments/audit SQL migration is confirmed live:
  ```text
  GET /complaints/10/comments -> count=0
  GET /complaints/10/audit -> count=0
  ```
- APK rebuild/install passed:
  ```text
  flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.18.165:8000
  Built E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
  adb install -r ...\app-debug.apk -> Success
  adb shell monkey -p com.example.civic_app -c android.intent.category.LAUNCHER 1 -> Events injected
  adb shell pidof com.example.civic_app -> 9240
  ```

## Admin Review / Community Discussion Pass - 2026-06-24

- Note: this section described the first backend/web-only pass. Flutter was later updated on 2026-06-25 for citizen comments and status label polish.
- Backend and React admin were updated with:
  ```text
  /review-queue
  /complaints/:id
  admin approve/reject/request-more-proof/assign/status endpoints
  comments/replies/votes endpoints
  ```
- Mobile safety assumptions remain unchanged:
  ```text
  manual_review reports do not earn points until admin approval/resolution
  rejected/fake reports are never reward-eligible
  evidence validation remains strict and separate
  ```
- New Supabase migration to run before comments/audit are usable:
  ```text
  E:\Vishwas\docs\admin_review_comments_schema.sql
  ```
- Latest backend/web verification is documented in:
  ```text
  E:\Vishwas\docs\HANDOFF_FOR_CHATGPT.md
  ```

## Assistant Dynamic Response / Gemini Quota Diagnosis - 2026-06-24

### Root Cause
- The backend and phone connection were healthy.
- `GEMINI_API_KEY` was loaded, but Gemini returned HTTP 429:
  ```text
  GenerateRequestsPerDayPerProjectPerModel-FreeTier
  limit=20
  model=gemini-2.5-flash
  ```
- The backend correctly entered `rule_fallback`, but its issue parser required
  exact words such as `pothole`. Android STT phrases visible in the screenshot,
  including `pot holes`, `holes in front of my road`, and `forth holes`, were
  not recognized and caused the repeated generic question.

### Fix
- Expanded fallback recognition for common pothole and STT variants:
  ```text
  pothole / potholes
  pot hole / pot holes
  road hole / road holes
  holes on/in/near a road or street
  observed STT rendering "forth holes"
  ```
- Fallback responses now confirm the interpreted issue context before taking
  the next safe action.
- Explicit corrections still override the prior issue type.
- Added a short Gemini quota cooldown so repeated phone turns do not hammer the
  API after a 429.
- API diagnostics expose safe codes only:
  ```text
  GEMINI_QUOTA_EXCEEDED
  GEMINI_QUOTA_COOLDOWN
  ```
- Gemini remains the primary planner. No Vapi or generic chatbot was added.

### Regression Results
```text
"there forth holes in front of my road..." -> pothole, get_location
"there are holes in front of my road..." -> pothole, get_location
"there are pot holes" -> pothole, get_location
"Actually it is water leakage" with prior pothole -> water_leakage, get_location
"Who is Virat Kohli?" -> bounded civic redirect, listen
```

### Deployment
- Backend restarted and is healthy on port 8000.
- This was a backend-only endpoint-compatible fix; no APK rebuild was required.
- Dynamic Gemini-generated wording will resume when Gemini quota is available.
  Until then, the improved contextual rule fallback keeps the workflow usable.

## Gallery MIME And Assistant Overflow Fix - 2026-06-24

### Root Cause
- The shared Flutter multipart helper used `MultipartFile.fromPath` without an
  explicit content type. Gallery files such as `scaled_1000607589.png` could
  therefore arrive as `application/octet-stream`.
- The assistant screen combined several fixed-height sections, a nested
  message list, validation content, typed input, and action buttons in one
  `Column`, causing `BOTTOM OVERFLOWED BY 27 PIXELS` on the phone.

### Flutter Fix
- Added direct dependencies:
  ```text
  mime
  http_parser
  ```
- `ApiService.postMultipart` now reads initial file bytes, calls
  `lookupMimeType`, applies known extension fallbacks, and passes an explicit
  `MediaType` to `MultipartFile.fromPath`.
- Known mappings include PNG, JPEG, WEBP, MP4, and MOV.
- The assistant body is now one keyboard-aware `SafeArea` + `ListView`.
  Messages, proof preview, validation details, typed input, and actions scroll
  together with bottom safe-area/keyboard padding.

### Backend Fix
- `/mobile/validate-evidence` now normalizes proof type using:
  ```text
  PNG magic bytes
  JPEG magic bytes
  RIFF...WEBP magic bytes
  supported filename extension fallback
  supported declared MIME fallback
  ```
- A real PNG sent as `application/octet-stream` is normalized to `image/png`.
- A real JPEG sent as `application/octet-stream` is normalized to
  `image/jpeg`.
- Unsupported binary is rejected with:
  ```text
  Unsupported proof file type. Please upload JPG, PNG, WEBP, or MP4.
  ```
- Evidence rules, video manual review, and the confidence >= 0.65 auto-submit
  guard remain unchanged.

### Files Changed
```text
E:\Vishwas\Civic-App\pubspec.yaml
E:\Vishwas\Civic-App\pubspec.lock
E:\Vishwas\Civic-App\lib\core\services\api_service.dart
E:\Vishwas\Civic-App\lib\features\issues\repositories\remote_issue_repository.dart
E:\Vishwas\Civic-App\lib\features\voice_report\screens\citizen_assistant_screen.dart
E:\Vishwas\backend\Team-Try\main.py
E:\Vishwas\backend\Team-Try\services\gemini_service.py
```

### Test Results
- Python compile passed.
- Flutter formatting passed.
- Targeted Flutter analysis has no errors in changed files; one pre-existing
  informational lint remains in `remote_issue_repository.dart`.
- MIME normalizer:
  ```text
  scaled_1000607589.png + application/octet-stream -> image/png
  photo.jpg + application/octet-stream -> image/jpeg
  photo.webp + application/octet-stream -> image/webp
  clip.mp4 + application/octet-stream -> video/mp4
  arbitrary payload.bin -> rejected
  ```
- Real endpoint PNG/JPG octet-stream tests reached AI validation. They were not
  rejected as unsupported MIME. Current Gemini and OpenAI quotas returned the
  existing fail-closed/manual-review response.
- Debug APK build succeeded:
  ```text
  E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
  ```

### APK / Physical Phone Verification
- APK installation succeeded on `1398144555000TQ`.
- App launched successfully with PID `13703`.
- The assistant screen exposed a scrollable Android semantics surface.
- Long assistant conversation content was scrolled on the physical phone.
- Logcat contained no `RenderFlex`, `BOTTOM OVERFLOWED`, or `overflowed by`
  messages before or after scrolling.

### Remaining Limitations
- Selecting a specific gallery image still requires manual interaction on the
  phone.
- Gemini/OpenAI quota remains the current external blocker for a successful AI
  verdict; fail-closed behavior is working.

## Gallery Proof And Bounded Question Handling - 2026-06-24

### Added Proof Options
- The assistant proof step now shows `Take Photo`, `Record Video`, `Upload
  Photo`, `Upload Video`, and `Submit for Manual Review`.
- Camera and gallery media use `image_picker`.
- Selected media stops at a preview showing media type, Camera/Gallery source,
  and filename. Citizens then choose `Verify Proof` or `Replace Proof`.
- Gallery images use the same strict `/mobile/validate-evidence` endpoint as
  camera images. Gallery origin does not make evidence trusted.
- Videos remain fail-closed/manual review because no semantic frame-validation
  pipeline exists.

### Planner And Scope
- Added actions: `upload_photo`, `upload_video`, and `answer_question`.
- Deterministic tests:
  ```text
  I already have a photo -> upload_photo
  I have a video -> upload_video
  Why do you need location? -> answer_question
  Who is Virat Kohli? -> listen + out-of-scope civic redirect
  ```
- Civic-reporting questions receive short bounded answers. Unrelated questions
  are not answered or browsed and are redirected to civic reporting.
- Typed input uses the same `/mobile/assistant-turn` path for reports,
  corrections, proof choices, and questions.

### Safety
- Auto-submit requires real GPS, media, `validation_status=verified`,
  `evidence_valid=true`, `matches_claimed_issue=true`, and confidence >= 0.65.
- A high-confidence request with false evidence flags returned
  `manual_review` and `safety_status=block_submit`.
- Unverified images can enter manual review only when explicitly recommended;
  they are never auto-submitted or reward-eligible.

### Files And Verification
- Changed the assistant screen, `services/gemini_service.py`, `main.py`, and
  both handoff documents.
- Python compile passed.
- Flutter assistant analysis passed with no issues.
- Backend planner HTTP tests passed.
- Physical iQOO test reached `Waiting for Proof` after a typed pothole report
  and real GPS; all four camera/gallery buttons were visible.
- Debug APK built and installed successfully:
  ```text
  E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
  device=1398144555000TQ
  ```

### Remaining Limitations
- Selecting and validating a real gallery fake/matching image requires manual
  media choice on the phone.
- Video semantic validation is intentionally unavailable; videos remain manual
  review.
- OpenAI image fallback may still be limited by account/project quota.

Correct wording:
```text
The assistant is not a generic chatbot. It is a Gemini-planned civic workflow agent. It can answer civic-reporting questions and handle corrections, but unrelated questions are safely redirected back to reporting.
```

## Citizen Assistant Speech Recognition Fix - 2026-06-24

### Root Cause
- The assistant called `speech_to_text.listen()` immediately after
  `flutter_tts.speak()`, but TTS was not configured to wait for playback
  completion. The recognizer could therefore start while the assistant was
  still speaking and return Android's `error_no_match`.
- The speech engine was also initialized on every listen attempt, and raw
  speech error codes were sent directly to the main UI.

### Files Changed
- Flutter only:
  ```text
  E:\Vishwas\Civic-App\lib\features\voice_report\screens\citizen_assistant_screen.dart
  E:\Vishwas\Civic-App\docs\HANDOFF_FOR_CHATGPT.md
  ```
- Backend planner, React dashboard, Supabase, Gemini planner logic, evidence
  validation, and reward rules were not changed.

### TTS / STT Timing
- TTS now uses:
  ```text
  awaitSpeakCompletion(true)
  ```
- Planner replies finish speaking before STT begins.
- The screen shows `Get ready`, waits 800 ms after TTS completion, then changes
  to `Listening now`.
- The microphone icon/glow is shown only while STT is actually listening.

### Speech Initialization And Listen Settings
- Microphone permission is checked before listening.
- Denied permission shows a clear explanation, typed fallback, and an
  `Open Settings` button.
- `SpeechToText` is initialized once and reused for later retries.
- Locale preference:
  ```text
  en_IN -> en_US -> system locale
  ```
- Listen options:
  ```text
  listenFor=30 seconds
  pauseFor=5 seconds
  partialResults=true
  cancelOnError=false
  listenMode=dictation
  ```
- Safe debug output includes availability, selected locale, listen
  start/stop, status, and speech error code only.

### Recovery And Typed Fallback
- `error_no_match` and speech timeout no longer appear as raw UI errors.
- The friendly recovery message is:
  ```text
  I couldn't hear that clearly. Please tap Try Again and speak after the listening indicator appears.
  ```
- `Try Again` starts a fresh listen session without restarting the assistant.
- `Type Instead` opens an inline text field. Typed text is added as a user
  message and sent to `/mobile/assistant-turn` through the same method used by
  a recognized speech transcript.
- The assistant displays these explicit stages:
  ```text
  Speaking
  Get ready
  Listening now
  Processing
  ```

### Verification
- Targeted analysis:
  ```text
  flutter analyze lib\features\voice_report\screens\citizen_assistant_screen.dart
  No issues found.
  ```
- `flutter test` found no executable tests in the existing test suite.
- Backend LAN health passed at:
  ```text
  http://192.168.18.165:8000/health
  ```
- Debug APK build:
  ```text
  SUCCESS
  E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
  ```
- APK installed successfully on:
  ```text
  1398144555000TQ (iQOO I2018, Android 13)
  ```
- App launched successfully after install.
- Physical-phone voice flow passed:
  ```text
  greeting remained in Speaking until TTS completed
  speech transcript was captured
  Gemini identified issue_type=pothole
  planner requested get_location
  real GPS was captured
  planner advanced to next_action=ask_for_proof
  ```
- The installed app was left open at `Waiting for Proof`.
- Silent-input recovery still needs a quiet manual run on the physical phone.
  The implemented path converts `error_no_match`/speech timeout into the
  friendly retry message and exposes both `Try Again` and `Type Instead`.

### Safety Preserved
- Gemini `/mobile/assistant-turn` remains active.
- Auto-submit still requires real GPS, proof media, successful validation,
  matching evidence, and confidence >= 0.65.
- Evidence validation remains separate and strict.

## Gemini-Planned Native Assistant Upgrade - 2026-06-24

### What Changed
- Added backend planner endpoint:
  ```text
  POST /mobile/assistant-turn
  ```
- Gemini model used:
  ```text
  gemini-2.5-flash
  ```
- Added Flutter repository model/method:
  ```text
  AssistantTurnResult
  RemoteIssueRepository.assistantTurn(...)
  ```
- Reworked `/citizen/assistant` into a Gemini-planned native Flutter workflow agent.
- Did not add Vapi to mobile. Did not weaken evidence validation or reward rules.

### Planner Contract
- Request includes:
  ```text
  citizen_id
  user_message
  current_state
  known_data
  ```
- Response is strict JSON with:
  ```text
  assistant_reply
  next_action
  issue_type
  clean_summary
  description
  missing_fields
  requires_user_confirmation
  safety_status
  reason
  ```
- Allowed actions:
  ```text
  listen
  get_location
  ask_for_proof
  open_camera_photo
  open_camera_video
  validate_evidence
  submit_report
  manual_review
  show_my_issues
  end
  ask_clarifying_question
  ```

### Deterministic Fallback
- If Gemini planner fails, backend uses rule fallback:
  ```text
  no issue -> listen
  issue without location -> get_location
  location without proof -> ask_for_proof
  proof without validation -> validate_evidence
  verified confidence >= 0.65 -> submit_report
  failed/quota/low confidence -> manual_review
  ```
- Backend has a final safety guard: if the planner asks to submit without real location, media, verified validation, and confidence >= 0.65, it rewrites the action to manual review/block submit.

### Flutter Wiring
- `/citizen/assistant` now calls `/mobile/assistant-turn` after:
  ```text
  start
  speech transcript
  GPS capture
  photo/video capture
  evidence validation
  errors
  ```
- Flutter still executes device actions:
  ```text
  speech_to_text listening
  flutter_tts replies
  geolocator GPS
  image_picker photo/video
  url_launcher maps
  ```
- UI now includes:
  ```text
  glowing assistant avatar
  state label
  next_action/safety/reason demo panel
  transcript bubbles
  GPS card
  proof preview
  validation details card
  result card
  end assistant button
  ```

### Tests Run
- Backend compile:
  ```text
  C:\Users\USER\AppData\Local\Programs\Python\Python312\python.exe -m compileall E:\Vishwas\backend\Team-Try
  PASSED
  ```
- Backend restarted with correct Python and `/debug-config`:
  ```text
  loaded_env_path=E:\Vishwas\backend\.env
  gemini_api_key_present=true
  openai_api_key_present=true
  ```
- Planner smoke test 1:
  ```text
  user_message="There is a pothole on this road."
  next_action=get_location
  issue_type=pothole
  ```
- Planner smoke test 2:
  ```text
  user_message="Actually it is water leakage, not pothole."
  known location present
  next_action=ask_for_proof
  issue_type=water_leakage
  ```
- Flutter format passed on changed files.
- Flutter analyze still exits 1 due existing warnings/info only; no compile-blocking errors from this upgrade.
- Debug APK build succeeded:
  ```text
  E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
  ```
- APK installed and launched:
  ```text
  adb install -r ...\app-debug.apk -> Success
  adb shell pidof com.example.civic_app -> 21158
  ```

### Validation / Rewards Integrity
- Evidence validation remains strict and separate from planner.
- Auto-submit still requires:
  ```text
  issue extraction
  real GPS
  proof media
  evidence_valid=true
  matches_claimed_issue=true
  confidence >= 0.65
  ```
- Fake/failed/manual-review reports do not receive leaderboard points until approved/resolved.
- OpenAI fallback remains image-validation fallback only. It is not the assistant brain. Latest known OpenAI fallback blocker remains account/project quota (`429 insufficient_quota`) when forced.

### Remaining Manual Checks
- Full phone mic/TTS/GPS/camera conversation still needs tapping through on the device.
- Fake table proof should still reject through `/mobile/validate-evidence`.
- Real civic image auto-submit should only pass if validation confidence >= 0.65.
- Phone browser backend health can be checked at:
  ```text
  http://192.168.18.165:8000/health
  ```

Correct summary:
```text
The assistant is a Gemini-planned, native Flutter voice workflow agent. Gemini decides the next safe action, Flutter executes device actions like GPS and camera, and backend validation controls whether a complaint can be auto-submitted or must go to manual review.
```

## OpenAI Key Loaded / Fallback Quota Result - 2026-06-24

### Safe Config
- Backend restarted with the Python runtime that has FastAPI installed:
  ```text
  C:\Users\USER\AppData\Local\Programs\Python\Python312\python.exe
  ```
- Current normal `/debug-config` result:
  ```text
  loaded_env_path=E:\Vishwas\backend\.env
  gemini_api_key_present=true
  gemini_api_key_prefix=AQ.Ab8
  openai_api_key_present=true
  openai_api_key_prefix=sk-pr
  cwd=E:\Vishwas\backend\Team-Try
  ```
- No full key was printed or written into docs.

### Normal Validation
- With normal Gemini + OpenAI config, Gemini succeeded first, so fallback did not run:
  ```text
  fake table as water_leakage -> HTTP 422
  provider=gemini
  evidence_valid=false
  recommendation=retake_proof
  ```
- Available blurry road image as `pothole` was also rejected by Gemini:
  ```text
  HTTP 422
  provider=gemini
  evidence_valid=false
  confidence=0.1
  recommendation=retake_proof
  validation_error_code=LOW_CONFIDENCE
  ```

### Controlled OpenAI Fallback Test
- Temporarily restarted backend with process-only:
  ```text
  GEMINI_API_KEY=invalid_for_openai_fallback_test
  ```
- This did not edit any env file. It forced Gemini to fail and confirmed OpenAI fallback was attempted.
- Fake table as `water_leakage` result:
  ```text
  HTTP 422
  provider=fail_closed
  evidence_valid=false
  recommendation=manual_review
  validation_error_code=AI_UNAVAILABLE
  gemini_error_code=GEMINI_API_KEY_INVALID
  OpenAI fallback failed with HTTP 429 insufficient_quota
  ```
- Interpretation:
  ```text
  OpenAI fallback wiring is active, but the configured OpenAI project/account currently has insufficient quota.
  ```
- Backend was restored afterward to normal Gemini + OpenAI config.

### Current Blocker
- OpenAI fallback cannot return `provider=openai` until the OpenAI account/project has available quota/billing.
- Fail-closed behavior is working: fake proof is not auto-submitted or verified.

## Env / Schema / OpenAI Fallback Recheck - 2026-06-24

### Env Path and OpenAI Status
- Actual backend env loader still uses:
  ```text
  E:\Vishwas\backend\.env
  ```
- Checked possible paths without printing secrets:
  ```text
  E:\Vishwas\backend.env             missing
  E:\Vishwas\backend\.env            exists, no OPENAI_API_KEY line
  E:\Vishwas\backend\Team-Try.env    missing
  E:\Vishwas\backend\Team-Try\.env   missing
  ```
- Restarted backend from:
  ```powershell
  cd E:\Vishwas\backend\Team-Try
  uvicorn main:app --host 0.0.0.0 --port 8000
  ```
- `/debug-config` safe result:
  ```text
  loaded_env_path=E:\Vishwas\backend\.env
  openai_api_key_present=false
  ```
- Manual action still needed:
  ```text
  Add OPENAI_API_KEY=<my_key> to E:\Vishwas\backend\.env
  Restart backend
  Recheck http://127.0.0.1:8000/debug-config
  ```

### Supabase Schema Result
- Attempted the requested DDL through the backend `execute_sql` RPC, but that RPC rejected DDL:
  ```text
  MIGRATION_FAILED
  APIError: syntax error at or near "TABLE"
  ```
- However, the schema issue is now resolved. A direct Supabase select confirmed all requested columns exist:
  ```text
  media_url
  media_type
  validation_status
  validation_confidence
  validation_provider
  reward_eligible
  auto_submitted
  citizen_id
  ```
- `/complaints` now works without the previous `media_url` error:
  ```text
  count=9
  ```

### Validation Results
- Fake table image as `water_leakage`:
  ```text
  HTTP 422
  provider=gemini
  evidence_valid=false
  confidence=1.0
  detected_issue_type=none
  recommendation=retake_proof
  ```
- Available local blurry road-surface image as `pothole`:
  ```text
  HTTP 422
  provider=gemini
  evidence_valid=false
  confidence=0.35
  detected_issue_type=none
  recommendation=retake_proof
  validation_error_code=LOW_CONFIDENCE
  ```
- OpenAI fallback result:
  ```text
  Not activated. Gemini succeeded on both validation calls, and OPENAI_API_KEY is still not loaded.
  ```
- No valid/verified complaint was inserted by these invalid validation calls.

## OpenAI Fallback Verification Attempt - 2026-06-24

### Backend Restart
- Restarted backend from:
  ```powershell
  cd E:\Vishwas\backend\Team-Try
  uvicorn main:app --host 0.0.0.0 --port 8000
  ```
- Backend health passed:
  ```text
  http://127.0.0.1:8000/health -> healthy
  ```

### Safe Config Check
- `/debug-config` loaded:
  ```text
  E:\Vishwas\backend\.env
  ```
- Safe key status:
  ```text
  gemini_api_key_present=true
  openai_api_key_present=false
  ```
- Presence-only file check found no `OPENAI_API_KEY` line in:
  ```text
  E:\Vishwas\backend.env             missing
  E:\Vishwas\backend\.env            exists, no OPENAI_API_KEY line
  E:\Vishwas\backend\Team-Try\.env   missing
  ```
- Result: OpenAI fallback could not be verified because the backend is not loading an OpenAI key yet. Do not print or commit the key; add it manually to `E:\Vishwas\backend\.env` or `E:\Vishwas\backend\Team-Try\.env`, then restart backend.

### Fake Evidence Test
- Test:
  ```text
  claimed_issue_type=water_leakage
  proof=generated office table image
  ```
- Result:
  ```text
  HTTP 422
  provider=gemini
  evidence_valid=false
  confidence=1.0
  detected_issue_type=none
  recommendation=retake_proof
  ```
- The proof was rejected as unrelated/non-civic. OpenAI fallback did not run because Gemini succeeded and no OpenAI key was loaded.

### Available Real/Local Image Test
- Tested local blurry road-surface style image:
  ```text
  E:\Vishwas\backend\Team-Try\temp_scaled_93b45944-0c43-4ce4-a881-4039d173939b7071266285765044493.jpg
  claimed_issue_type=pothole
  ```
- Result:
  ```text
  HTTP 422
  provider=gemini
  evidence_valid=false
  confidence=0.35
  detected_issue_type=none
  recommendation=retake_proof
  validation_error_code=LOW_CONFIDENCE
  ```
- Auto-submit did not work for this image because confidence was below 0.65 and the image did not clearly show a pothole.

### Mobile UI Check
- Small UI patch applied because validation details needed to include provider:
  ```text
  lib/features/voice_report/screens/voice_assisted_report_screen.dart
  lib/features/voice_report/screens/citizen_assistant_screen.dart
  ```
- Validation failure UI now surfaces:
  ```text
  provider
  visible issue
  detected issue type
  confidence
  recommendation
  ```
- Rebuilt APK because mobile code changed:
  ```powershell
  flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.18.165:8000
  ```
- Build succeeded:
  ```text
  E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
  Size: 186046601 bytes
  ```

### Remaining Blocker
- The only blocker for OpenAI fallback verification is env placement: `OPENAI_API_KEY` is not present in the env file loaded by backend.

## Latest Agentic Assistant / Rewards Status - 2026-06-24

### Scope Completed
- Added the call-like citizen assistant route:
  ```text
  /citizen/assistant
  ```
- Added a real rewards leaderboard route:
  ```text
  /citizen/leaderboard
  ```
- Kept the existing voice report route intact:
  ```text
  /citizen/voice-report
  ```
- Did not write or commit secrets. A pasted OpenAI key was not stored in any file and should be revoked/rotated.

### Packages / Mobile Behavior
- Added:
  ```yaml
  flutter_tts: ^4.2.2
  ```
- Existing packages used by the assistant:
  ```text
  speech_to_text, geolocator, image_picker, url_launcher
  ```
- Assistant behavior:
  ```text
  Start Assistant -> TTS greeting -> STT transcript -> /mobile/voice-prepare
  -> real GPS capture -> photo/video proof prompt -> /mobile/validate-evidence
  -> safe auto-submit only when validation passes -> My Issues / manual review choices
  ```
- The assistant opens camera/video capture only after user action. It does not secretly capture media.

### Provider Fallback Behavior
- Backend validation now tries Gemini first:
  ```text
  gemini-2.5-flash
  ```
- If Gemini fails because of quota, invalid key, timeout, or invalid JSON, the backend tries OpenAI vision fallback only when `OPENAI_API_KEY` exists in the backend environment.
- OpenAI fallback model currently configured in code:
  ```text
  gpt-4o-mini
  ```
- If all providers fail, the response fails closed:
  ```text
  evidence_valid=false
  recommendation=manual_review
  provider=fail_closed
  auto-submit blocked
  ```
- Full keys are not logged. `/debug-config` exposes only safe presence flags and short prefixes.

### Manual OpenAI Key Setup
- A safe template was added at:
  ```text
  E:\Vishwas\backend\env.example
  ```
- The backend already loads the real env file from:
  ```text
  E:\Vishwas\backend\.env
  ```
- To enable OpenAI fallback manually, add this line to `E:\Vishwas\backend\.env`:
  ```text
  OPENAI_API_KEY=<your_rotated_key_here>
  ```
- Restart the backend after editing:
  ```powershell
  cd E:\Vishwas\backend\Team-Try
  uvicorn main:app --host 0.0.0.0 --port 8000
  ```
- Confirm safely through `/debug-config`; it should show `openai_api_key_present: true` and only a short prefix, not the full key.

### Current Provider Test Status
- Current backend `/debug-config` showed:
  ```text
  GEMINI_API_KEY present: true
  OPENAI_API_KEY present: false
  ```
- OpenAI fallback is implemented but not live-tested because no backend `OPENAI_API_KEY` is configured.
- Latest fake evidence test used Gemini successfully and rejected unrelated/table-like evidence:
  ```text
  HTTP 422
  provider=gemini
  evidence_valid=false
  confidence=1.0
  recommendation=retake_proof
  ```
- Earlier Gemini quota failures can still happen; those remain fail-closed/manual-review, not success.

### Safe Auto-Submit Rules
- Auto-submit only when all are true:
  ```text
  transcript extraction succeeds
  real GPS exists
  proof media exists
  AI evidence validation succeeds
  confidence >= 0.65
  evidence matches claimed issue
  ```
- Manual review is used for:
  ```text
  AI quota/provider failure
  unsupported video semantic validation
  low confidence
  proof mismatch
  GPS unavailable
  explicit user choice
  ```

### Leaderboard / Rewards
- Backend endpoints added:
  ```text
  GET /mobile/leaderboard
  GET /leaderboard
  ```
- Points are computed from complaint metadata/status, not fake demo counts:
  ```text
  +10 verified accepted report
  +25 resolved verified/approved report
  +5 community_confirmations >= 3
  +5 video bonus only after approved/resolved
  -10 rejected/fake/spam
  0 for failed AI validation or manual_review until approved/resolved
  ```
- Current demo/seed complaints return 0 reward points unless they have verified/approved metadata. This avoids fake leaderboard rewards.

### My Issues
- My Issues cards now show:
  ```text
  validation status
  reward eligibility
  media type
  ```
- Assistant submissions invalidate/refetch My Issues and leaderboard providers after submit.

### Phone / APK Verification
- Phone connected:
  ```text
  1398144555000TQ device
  I2018 / Android 13 (API 33)
  ```
- Fresh debug APK build succeeded:
  ```powershell
  flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.18.165:8000
  ```
- APK path:
  ```text
  E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
  ```
- Latest APK installed and launched:
  ```text
  adb install -r ...\app-debug.apk -> Success
  adb shell monkey -p com.example.civic_app -c android.intent.category.LAUNCHER 1 -> Events injected
  adb shell pidof com.example.civic_app -> 8273
  ```

### Verification Notes / Remaining Limitations
- `flutter analyze` still exits 1 because of existing warnings/info, not compile-blocking errors. Current count: 64 issues, mostly deprecated APIs and unused imports/fields.
- Full real-world assistant flow with mic/TTS/GPS/camera still needs manual tapping on the physical phone.
- Full valid civic-photo auto-submit was not tested with a real street issue.
- Phone-browser backend health should be manually checked at:
  ```text
  http://192.168.18.165:8000/health
  ```
- Future Flutter versions may require Kotlin Gradle Plugin migration; current debug APK build succeeds.

## Real AI Evidence Validation and GPS Hardening - 2026-06-24

### Root Cause of "AI Analysis Failed"
- Backend image validation previously used `genai.upload_file(...)`.
- That path failed with Gemini API-key/discovery errors even when text Gemini calls had sometimes worked.
- Repaired `validate_civic_evidence(...)` to send inline image bytes directly to the Gemini multimodal model instead of uploading the file first.
- Model used:
  ```text
  gemini-2.5-flash
  ```

### Current Gemini Vision Status
- Gemini Vision path now reaches `generate_content` with inline image bytes.
- Current live result is still blocked by Gemini quota:
  ```text
  429 quota exceeded for gemini-2.5-flash free tier
  ```
- The system fails closed:
  ```text
  evidence_valid=false
  recommendation=manual_review
  validation_error_code=AI_UNAVAILABLE
  ```
- No fake/demo success is returned. Auto-submit is blocked until Gemini quota/key/project access is valid.

### Safe Backend Diagnostics Added
`POST /mobile/validate-evidence` now logs safe debug facts only:

```text
endpoint hit
file received yes/no
filename
content_type
file size
claimed_issue_type
transcript present yes/no
latitude/longitude present yes/no
Gemini key present yes/no
Gemini key prefix first 5 chars only
Gemini model
loaded env path
validation error code/recommendation/confidence
```

It does not log full API keys, base64 images, or secrets.

### Fake Evidence Test
Tested generated table-like PNG as:

```text
claimed_issue_type=water_leakage
transcript=There is water leakage here
latitude=26.85123
longitude=80.95123
```

Result:

```text
HTTP 422
success=false
message=The uploaded proof does not clearly match the reported issue.
validation_error_code=AI_UNAVAILABLE
```

No verified/auto-submitted complaint was inserted.

### GPS Hardening
Backend now rejects:

```text
missing latitude/longitude
out-of-range latitude/longitude
0,0 coordinates
known demo/sample coordinates: 26.8467,80.9462 and 26.8,80.9
```

Applied to:

```text
POST /upload_details
POST /mobile/voice-prepare
POST /mobile/validate-evidence
POST /mobile/report-submit
```

Flutter voice flow no longer falls back to `0` coordinates during validation/submission. It blocks if current GPS is missing.

### Mobile GPS UI
Voice Assisted Report now shows:

```text
Latitude
Longitude
Accuracy in meters
Open in Maps button
```

The Maps button opens:

```text
https://www.google.com/maps?q=<lat>,<lng>
```

Added package:

```yaml
url_launcher: ^6.3.1
```

### Real Phone GPS Verification
- Physical phone remains connected as:
  ```text
  1398144555000TQ device
  ```
- `adb shell dumpsys location` shows active/recent fused and GPS providers with real accuracy values, including GPS horizontal accuracy around 7.7m and fused/network around 18.2m.
- Android redacts exact coordinates in `dumpsys`, so exact lat/lng must be verified inside the app UI after granting location.

### Flutter UI Validation Failure Behavior
Validation failure now distinguishes:

```text
AI unavailable
proof mismatch
low confidence
unsupported video validation
backend unreachable
```

The failure card displays:

```text
visible issue
detected issue type
confidence
recommendation
reason
```

### Build / Install Result
Command:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.18.165:8000
```

Result:

```text
Built build\app\outputs\flutter-apk\app-debug.apk
```

APK:

```text
E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
Size: 186004014 bytes
```

Installed and launched on phone:

```text
adb install -r ...\app-debug.apk -> Success
adb shell monkey -p com.example.civic_app -c android.intent.category.LAUNCHER 1 -> Events injected
adb shell pidof com.example.civic_app -> 20626
```

### Remaining Limitations
- Real Gemini visual validation is implemented, but currently blocked by Gemini quota (`429`) for the configured project/model.
- Until quota/key/project access is fixed, AI visual validation fails closed and blocks auto-submit.
- Exact phone GPS coordinates still require in-app verification because ADB redacts lat/lng in location dumps.
- Existing Flutter analyzer warnings remain; no blocking errors were introduced.

## Agentic Mobile Reporting Upgrade - 2026-06-24

### Scope
- Upgraded the Flutter citizen app with a Voice Assisted Report flow.
- Added minimal FastAPI support endpoints for mobile prepare/validate/submit.
- Did not modify `.env` files or expose secrets.
- Existing `/voice-report`, dashboard, map, analytics, and community endpoints were left intact.

### Mobile Flow Added
New route:

```text
/citizen/voice-report
```

New screen:

```text
lib/features/voice_report/screens/voice_assisted_report_screen.dart
```

Flow implemented:

```text
Voice/text input -> backend issue extraction -> GPS location -> photo/video proof capture -> evidence validation -> submit -> My Issues/Recent Issues refresh
```

UI states implemented:

```text
idle, listening, transcript_ready, extracting_issue, getting_location,
waiting_for_proof, validating_proof, submitting, success,
validation_failed, error
```

Home screen now exposes:

```text
Start Voice Report
Manual report icon
Voice Report floating action button
```

### Packages Added
Added:

```yaml
speech_to_text: ^7.0.0
```

Existing packages reused:

```text
permission_handler, geolocator, image_picker, shared_preferences, uuid
```

Android permission added:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

### Backend Endpoints Added
Added minimal mobile endpoints in `E:\Vishwas\backend\Team-Try\main.py`:

```text
POST /mobile/voice-prepare
POST /mobile/validate-evidence
POST /mobile/report-submit
```

`/mobile/voice-prepare` extracts structured fields but does not insert a complaint.

`/mobile/validate-evidence` validates proof before auto-submit. If validation fails, it returns 422 and does not insert.

`/mobile/report-submit` inserts only after validation or explicit video manual-review flow.

Existing `/voice-report` remains unchanged for the earlier Vapi/web path.

### Evidence Validation Behavior
Added `validate_civic_evidence(...)` in:

```text
E:\Vishwas\backend\Team-Try\services\gemini_service.py
```

Strict rules are encoded in the prompt:

```text
- unrelated indoor/random image -> invalid
- water leakage requires visible water/leak/drain/wet-road evidence
- pothole requires visible road/pothole surface damage
- confidence below 0.65 -> no auto-submit
- no invented pipeline burst from unrelated table/object images
```

Important limitation:

```text
The configured Gemini key currently returns API_KEY_INVALID for Vision calls.
Because of that, image validation currently fails closed into manual_review/retake behavior.
This still blocks fake auto-submit, but live Gemini Vision semantic validation is not confirmed until the key is fixed.
```

Video support:

```text
Video capture is supported with image_picker.
Video upload path is implemented.
Full video semantic validation is not implemented.
Video evidence is marked manual_review instead of overclaimed as AI-verified.
```

### Fake Image/Table Test Result
Test sent a generated table-like PNG as proof for:

```text
claimed_issue_type=water_leakage
transcript=There is water leakage here
```

Endpoint:

```text
POST /mobile/validate-evidence
```

Result:

```json
{
  "success": false,
  "requires_manual_review": true,
  "message": "The uploaded proof does not clearly match the reported issue."
}
```

No complaint was inserted by validation failure.

### My Issues Fix
Added persistent citizen identity service:

```text
lib/core/services/citizen_identity_service.dart
```

Behavior:

```text
- uses logged-in user id when available
- otherwise creates persistent mobile_user_<uuid>
- manual and voice submissions use the same id
- My Issues filters by the same id
```

Removed the old hardcoded My Issues filter behavior:

```text
Praveen / user_001
```

Debug-safe log added:

```text
Submitting report for citizen_id: <masked id>
```

### Build and Run Results
Backend syntax check:

```text
python -m compileall backend\Team-Try
PASSED
```

Backend health:

```text
http://127.0.0.1:8000/health
status: healthy
```

Mobile prepare endpoint smoke test:

```text
POST /mobile/voice-prepare
Transcript: There is a pothole on this road
Result: success=true, detected_category=pothole
```

Flutter analyze:

```text
No blocking errors.
Existing project warnings remain, mostly deprecated withOpacity/value usage and unused imports/fields.
```

Debug APK build:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.18.165:8000
```

Result:

```text
Built build\app\outputs\flutter-apk\app-debug.apk
```

APK path:

```text
E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
```

Physical phone install/launch:

```text
adb install -r ...\app-debug.apk -> Success
adb shell monkey -p com.example.civic_app -c android.intent.category.LAUNCHER 1 -> Events injected
adb shell pidof com.example.civic_app -> 14258
```

Phone:

```text
1398144555000TQ device
iQOO / I2018 / Android 13
```

### Remaining Limitations
- Phone-browser `/health` manual confirmation is still needed from the user.
- Live Gemini Vision validation is blocked by the currently invalid Gemini API key; validation fails closed instead of accepting fake media.
- Video semantic validation is manual-review only.
- Full end-to-end real pothole-photo submission was not physically tested because it requires real-world proof capture on the phone.
- Flutter prints future Kotlin Gradle Plugin warnings for `shared_preferences_android` and `speech_to_text`; build still succeeds.

## Scope
- Worked only inside `E:\Vishwas\Civic-App`.
- Did not modify FastAPI backend, React dashboard, Supabase, Gemini logic, or `.env` files.
- Main change: adjusted Android Gradle memory/Jetifier settings to resolve the managed Java heap OOM during `JetifyTransform`.

## Phone Connection
Phone is connected and authorized.

```text
List of devices attached
1398144555000TQ	device
```

`flutter devices` detected:

```text
I2018 (mobile) - 1398144555000TQ - android-arm64 - Android 13 (API 33)
```

## Backend Health
Laptop-side backend health check passed:

```text
http://192.168.18.165:8000/health
status: healthy
model_mode: fallback
```

Phone browser `/health` verification: user was asked to open `http://192.168.18.165:8000/health`; final user confirmation is still needed.

## Final Gradle Settings
`E:\Vishwas\Civic-App\android\gradle.properties` final values:

```properties
org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.configureondemand=false
android.useAndroidX=true
android.enableJetifier=false
```

Jetifier status: disabled. This avoided the previous `JetifyTransform` heap OOM path. No AndroidX/dependency error appeared with Jetifier disabled.

## Cleanup Performed
- Stopped stale `dart`, `java`, `gradle`, and `flutter` processes where present.
- Ran `android\gradlew --stop`.
- Ran `flutter clean`.
- Deleted generated `android\.gradle`.
- Removed generated heap dump files from failed OOM diagnostics:
  - `android\java_pid6372.hprof`
  - `android\java_pid7692.hprof`

## Flutter Run Result
Command attempted:

```powershell
flutter run -d 1398144555000TQ --dart-define=API_BASE_URL=http://192.168.18.165:8000
```

The command timed out in the tool without returning incremental output, but it completed enough of the build to produce `app-debug.apk`.

To verify the app on the phone, the generated APK was installed and launched directly:

```powershell
adb install -r E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p com.example.civic_app -c android.intent.category.LAUNCHER 1
adb shell pidof com.example.civic_app
```

Result:

```text
Performing Streamed Install
Success
Events injected: 1
10877
```

This confirms the debug app installed and launched on the physical iQOO/I2018 phone.

## APK Build Result
Explicit debug APK build succeeded:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.18.165:8000
```

Build output:

```text
Built build\app\outputs\flutter-apk\app-debug.apk
```

APK path:

```text
E:\Vishwas\Civic-App\build\app\outputs\flutter-apk\app-debug.apk
```

APK size at verification:

```text
160752629 bytes
```

## Remaining Blocker
No remaining Android build blocker.

Notes:
- Flutter still prints future-compatibility warnings about Kotlin Gradle Plugin usage and `shared_preferences_android`.
- Android SDK XML version warning still appears, but it did not block the debug build.
- The APK/build folders were not committed.
