# URL Inbox Release Checklist

## 1) Build and Quality Gate
- [ ] `flutter analyze` has zero issues
- [ ] `flutter test` passes
- [ ] Android debug and release builds complete
- [ ] iOS archive build completes in Xcode

## 2) iOS Share Extension (Critical)
- [ ] `Runner` target has App Group capability: `group.com.example.urlInbox`
- [ ] `ShareExtension` target has the same App Group capability
- [ ] Both targets use valid provisioning profiles with App Group enabled
- [ ] Share from Safari/X/Instagram opens `URL Inbox` in share sheet and link is ingested

## 3) Android Share Flow
- [ ] Share from Chrome/X/Instagram triggers URL ingestion
- [ ] No white screen when app is opened via share
- [ ] Duplicate links are de-duplicated by normalized URL

## 4) Data Safety
- [ ] Existing user DB upgrades without data loss
- [ ] New install creates `links`, `tags`, and `folders` tables correctly
- [ ] `source_app`, `last_opened_at`, and other newer columns are present after upgrade

## 5) Notifications
- [ ] Reminder notification can be enabled/disabled from settings
- [ ] Notification appears only when unread count > 0

## 6) Store Metadata
- [ ] App icon and screenshots prepared for phone sizes
- [ ] App description and keyword set prepared
- [ ] Support contact email prepared
- [ ] Privacy policy URL prepared and reachable
- [ ] Privacy policy reflects current auth/cloud behavior

## 7) Manual Regression Pass
- [ ] Save URL manually
- [ ] Save URL from share intent
- [ ] Search by keyword/domain/tag
- [ ] Folder create/select/delete
- [ ] Tag add/remove
- [ ] Open original URL
- [ ] Theme switch (light/dark)
