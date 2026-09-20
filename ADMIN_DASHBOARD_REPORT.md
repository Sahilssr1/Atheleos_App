# Atheleos Admin Dashboard — Discovery & Product Report

**Prepared:** 10 September 2026  
**Scope:** planning only; no app or backend implementation is included in this report.

## Decision

Yes—build the administrative product as a separate, private web application in
this repository. It should use the same Firebase project and the existing
Cloudflare media infrastructure, while remaining completely separate from the
Flutter client.

The admin console should **not** give a browser user unrestricted access to
Firestore, Cloudflare R2, Cloud Functions, deployment credentials, or source
code. It should expose carefully designed, audited operations such as “approve
this verification application” or “remove this post.” Those operations are
performed by a server-side Admin API after checking the staff member’s role.

There is no need to remove the admin site when the mobile app launches. Deploy
it separately (for example, at `admin.atheleos.com`), restrict sign-in to staff,
and keep its source alongside the mobile app for ongoing operations.

## What already exists in Atheleos

The current Flutter app is backed by Firebase Authentication and Firestore,
with Cloudflare R2/Worker plus Firebase Functions for media upload and video
processing. The product currently includes:

| Area | Existing data / capability |
| --- | --- |
| Accounts and profiles | `users`, username registry, Athlete, Coach, Brand, and Federation profile variants; profile settings, privacy, device sessions, blocks, mutes, hidden keywords, followers, and following. |
| Verification | Per-user `verification_applications` and protected profile fields: `verified`, `verificationStatus`, `verificationBadge`, `verificationLevel`, decision date, decision reason, and submitted request details. |
| Social content | `posts` (including clips), likes, comments, stories, bookmarks, shares, mentions, and counters. |
| Events | `events` with owners and participant subcollections. |
| Communication | Chat rooms, messages, user notification inboxes, FCM device tokens, and a `mail` delivery queue. |
| Trust and support | `reports` with description, device/app context, screenshots, status, and resolution. |
| Media platform | `media`, `processing_jobs`, `media_references`, a dead-letter-job collection, Cloudflare R2 objects, video processing, deduplication, reference counting, and cleanup jobs. |
| Product configuration | `system_data/sports_hierarchy`, already streamed by the Flutter feed. |

The Firestore rules explicitly reserve verification decisions and report
resolution to trusted server-side code; the customer app cannot make those
decisions directly. That is the right foundation for an admin console.

## Recommended first-version navigation

1. **Overview** — today/7-day/30-day activity, pending verification and report
   counts, media failures, new accounts by role, and operational alerts.
2. **Verification queue** — review Athlete, Coach, Brand, and Federation
   applications; open supporting documents; approve, reject with a reason, or
   request more information; see full decision history.
3. **People** — search by UID, username, name, email, phone, role, sport, city,
   account state, and verification state. Open a unified profile timeline.
4. **Content moderation** — filter posts, clips, stories, comments, events, and
   reported media; view the target in context; hide, restore, remove, or
   escalate it, with a stated reason.
5. **Reports and support** — triage open reports, assign an owner, add internal
   notes, link a person/content item, resolve the case, and reply through an
   approved support channel.
6. **Media operations** — inspect media ownership and references, failed or
   stuck processing jobs, dead-letter jobs, reference-count discrepancies, and
   safe deletion candidates.
7. **Events** — find, inspect, correct, cancel, or remove an event under a
   documented moderation workflow.
8. **Announcements and configuration** — maintain the sports hierarchy and,
   later, manage controlled announcements, feature flags, and policy text.
9. **Analytics** — role/sport/location growth, active users, content and event
   activity, verification turnaround, report turnaround, and media health.
10. **Audit log** — every sensitive read or write, including who acted, why,
    affected IDs, before/after values (with sensitive fields redacted), time,
    and request/correlation ID.

## Important workflows

### Verification

Use a collection-group queue over `verification_applications`, not a manual
search through individual users. The decision action must atomically update:

- the application (`pending`, `underReview`, `approved`, `rejected`, or
  `moreInfoRequired`);
- the user’s protected verification fields and badge/level;
- a verification decision-history record;
- an audit-log record; and
- the user notification/email.

Approvals and rejections should require a reviewer note. A second reviewer or
super-admin approval is recommended for high-value Federation and Brand
accounts. Verification evidence must be private and delivered to authorized
reviewers using short-lived URLs—not through publicly readable media URLs.

### Moderation and account actions

Start with reversible actions: content `hidden`/`restored`, account
`suspended`/`reinstated`, and media `quarantined`. Permanent deletion should be
a distinct, confirmed action with an audit record and a retention window.

Do not make private chat content generally searchable. It should only be
available to a narrowly permitted safety/escalation role, for a documented
case, and every access must be logged. A normal support or content moderator
does not need broad message access.

### Media deletion

The console must not directly delete an R2 object first. A server action should
check all `media_references`, choose a safe action (detach, quarantine, or
delete), update Firestore consistently, delete all media variants, and log the
outcome. This preserves the existing reference-count and cleanup design.

## Staff roles and permissions

| Role | Intended permissions |
| --- | --- |
| Super admin | Manage staff roles, all operational actions, policy/configuration changes, and audited emergency access. Very few people. |
| Operations admin | Users, verification, reports, events, media workflows, and announcements; no staff-role administration. |
| Verification reviewer | Read submitted profile evidence; make documented verification decisions only. |
| Content moderator | Work reports and public content; hide/restore/escalate content; no private chat search or staff management. |
| Support agent | Locate users and assigned cases; add notes and approved replies; no verification decisions, deletions, or private-message access. |
| Media operator | View pipeline state and retry/quarantine/delete through safe workflow; no account or verification decisions. |
| Analyst | Read aggregated, privacy-minimized metrics only. |

Roles should be enforced by Firebase Auth custom claims plus a server-side
permission policy. Firestore UI checks are useful for presentation, but are not
the security boundary.

## Required backend additions

Build a small trusted Admin API in Firebase Functions (or an equivalent
server-only API) using the Firebase Admin SDK. Example operations:

- `searchUsers`, `getUserCaseHistory`, `setAccountState`
- `listVerificationQueue`, `decideVerification`
- `listReports`, `assignCase`, `resolveCase`
- `moderateContent`, `restoreContent`, `moderateEvent`
- `getMediaDetails`, `retryMediaJob`, `quarantineMedia`, `deleteMediaSafely`
- `getDashboardMetrics`, `updateSportsHierarchy`

Each endpoint must verify the caller’s Firebase ID token, enforce the
permission, validate the request, write an audit event, and return only the
minimum data the role needs. Bulk actions need dry-run previews, confirmation,
small batch limits, and resumable progress.

Add these server-managed records before building broad admin features:

| New record | Why it is needed |
| --- | --- |
| `admin_audit_logs` | Immutable record of sensitive reads/writes and decisions. |
| `moderation_cases` / `moderation_actions` | Case ownership, targets, reasons, internal notes, evidence, status, and reversible actions. |
| `admin_notes` | Private, role-limited notes linked to a user, report, or verification case. |
| `daily_metrics` (or analytics warehouse) | Fast dashboard charts without repeatedly scanning production collections. |
| `admin_config` / feature-flag records | Versioned configuration with safe rollback and approval controls. |

The existing generic `reports` records are currently technical/support reports.
For full content moderation, extend them or introduce a dedicated report schema
with `reporterId`, `targetType`, `targetId`, `reason`, `evidence`, `status`,
`assignedTo`, and `resolution`.

## Current readiness and security work to complete first

1. **Protect server credentials.** `functions/src/index.ts` contains a fallback
   admin secret. Remove the fallback, rotate the deployed secret, store it only
   in Firebase/Cloudflare secret management, and never ship it to the web app.
2. **Verify all privileged calls.** The video-processing HTTP function currently
   checks for a bearer-header shape but should verify the Firebase token or use a
   service-to-service credential before it reads or changes a job.
3. **Tighten media and job permissions.** `media`, `processing_jobs`, and
   `media_references` are currently writable by any signed-in user in the
   Firestore rules. Move privileged workflow writes behind server APIs and give
   clients only the narrow reads/writes required by upload status.
4. **Make verification documents private.** Do not place sensitive identity or
   certification files in the public media namespace. Use a private R2 prefix
   and short-lived, reviewer-authorized downloads.
5. **Define account states.** The app currently has `isDeleted` but needs a
   server-managed state model such as `active`, `restricted`, `suspended`,
   `deleted`, plus reason, actor, timestamps, expiry, and appeal information.
6. **Normalize schemas and add indexes.** Some profile fields support legacy
   aliases (`name`/`displayName`/`fullName`, etc.). Before broad search and
   analytics, make the admin API return a canonical view and add the required
   Firestore indexes for verification/report status, roles, created dates, and
   collection-group queries.
7. **Use least privilege and audit retention.** Require MFA for staff, an
   allow-listed staff domain, short sessions, re-authentication before dangerous
   actions, rate limits, audit-log monitoring, backups, and a data-retention
   policy.

These are baseline production safeguards, not dashboard features to postpone.

## Repository and deployment structure

Recommended structure:

```text
atheleos/
├── flutter/                 # Existing Flutter mobile client
├── admin/                   # New private admin website (recommended: Next.js + TypeScript)
├── functions/               # Firebase Functions, including the Admin API
├── cloudflare_worker/       # R2 upload/media service
├── shared-contracts/        # Optional shared schemas/types and API contracts
├── firestore.rules
└── firestore.indexes.json
```

`flutter/web/` is the Flutter app’s web build target; it should not contain the
separate admin product. A top-level `admin/` folder is clearer, has its own
dependencies/build/deployment, and does not increase the mobile app binary.

Next.js with TypeScript is the recommended admin front end because it works
well for data-dense staff tools and can make authenticated requests to a
server-side API. Flutter Web is also technically viable if keeping one UI
technology is more valuable to the team, but it does not remove the need for a
server-side Admin API or change the security architecture.

Deploy the Flutter app and admin site independently. For launch, the mobile app
ships normally; the admin site remains available only at a private staff URL.
It is not something that must be removed from the app because it was never
bundled into the app.

## Delivery order

| Phase | Outcome |
| --- | --- |
| 0 — Foundation | Rotate secrets, close privileged client writes, define staff roles, add custom claims, Admin API guard, audit logs, private evidence storage. |
| 1 — Core operations | Staff sign-in, dashboard, people search, verification queue, report triage, basic public-content moderation. |
| 2 — Reliable operations | Account states, safe media controls, event moderation, internal case notes, notifications, retries, exports. |
| 3 — Intelligence | Scheduled aggregates, analytics, SLA/queue alerts, feature configuration, quality and fraud signals. |
| 4 — Advanced governance | Two-person approval, appeals, legal-hold/retention processes, warehouse/BI integration, automated moderation assistance. |

## Definition of done for the first release

The first production release is ready when authorized staff can securely sign
in; find a person, verification application, report, or public content item;
make only the actions allowed by their role; see a reliable outcome in the
mobile app; notify the affected user where appropriate; and produce a complete
audit trail. It is not ready merely because an administrator can edit arbitrary
Firestore documents from a browser.
