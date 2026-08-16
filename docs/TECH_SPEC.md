# AAYSA Tournament Platform Technical Specification

Version: v0.2
Date: 2026-08-16

## 1. Architecture Decision

The project will use a web-first architecture with a Capacitor native shell:

- Frontend: Next.js, React, TypeScript.
- Backend: Next.js API routes or Node.js services in the same app initially.
- Database: PostgreSQL.
- ORM: Prisma.
- Hosting: Vercel.
- Mobile shell: Capacitor for iOS and Android.
- Payments: Stripe.
- Email: Resend or comparable transactional email provider.
- Push: Capacitor-compatible push notification implementation, likely APNs/FCM through a wrapper service.

Core product UI is shared between web and mobile app. The native app layer provides only device capabilities:

- Push notifications.
- Camera and QR scanning.
- Deep links.
- Secure storage.
- Native maps/navigation handoff.
- Native share.

The app should not be a thin WKWebView wrapper that only opens the public website. It should include app identity, stored login, deep links, push, QR check-in, and native sharing.

## 2. Repository Structure

Recommended initial structure:

```text
aaysa-tournament/
├── docs/
│   ├── PRD.md
│   └── TECH_SPEC.md
├── prisma/
│   └── schema.prisma
├── public/
├── src/
│   ├── app/
│   ├── components/
│   ├── lib/
│   ├── server/
│   └── styles/
├── ios/
├── android/
├── capacitor.config.ts
├── package.json
└── README.md
```

## 3. Main Domains

- User and identity.
- Athlete.
- Club.
- Team.
- Tournament.
- Event session.
- Division.
- Venue and field.
- Registration.
- Roster entry.
- Legal document and acceptance.
- Promo code.
- Payment.
- Game.
- Score.
- Standing.
- Notification.
- Check-in.

## 4. Data Model Draft

The first Prisma schema should include the following core models. Names may be adjusted to match final implementation conventions.

```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  phone     String?
  role      UserRole @default(PARENT)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

enum UserRole {
  PARENT
  TEAM_MANAGER
  ORGANIZER
  ADMIN
}

model Athlete {
  id        String   @id @default(cuid())
  firstName String
  lastName  String
  dob       DateTime
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Club {
  id        String   @id @default(cuid())
  name      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Team {
  id        String   @id @default(cuid())
  name      String
  clubId    String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Tournament {
  id          String   @id @default(cuid())
  slug        String   @unique
  name        String
  description String?
  status      TournamentStatus @default(DRAFT)
  startsAt    DateTime?
  endsAt      DateTime?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}

enum TournamentStatus {
  DRAFT
  REGISTRATION_OPEN
  REGISTRATION_CLOSED
  SCHEDULED
  LIVE
  COMPLETED
  CANCELLED
}

model EventSession {
  id           String   @id @default(cuid())
  tournamentId String
  name         String
  startsAt     DateTime
  endsAt       DateTime?
}

model Division {
  id           String   @id @default(cuid())
  tournamentId String
  name         String
  minBirthDate DateTime?
  maxBirthDate DateTime?
  minRoster    Int      @default(5)
  maxRoster    Int      @default(7)
}

model Registration {
  id             String   @id @default(cuid())
  tournamentId   String
  divisionId     String
  teamId         String?
  managerUserId  String?
  status         RegistrationStatus @default(DRAFT)
  baseAmountCents Int
  discountCents   Int @default(0)
  feeCents        Int @default(0)
  totalCents      Int
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt
}

enum RegistrationStatus {
  DRAFT
  PENDING_PAYMENT
  PAID
  WAIVER_INCOMPLETE
  ELIGIBILITY_REVIEW
  READY
  CANCELLED
  REFUNDED
}

model RegistrationRosterEntry {
  id             String   @id @default(cuid())
  registrationId String
  athleteId      String?
  firstName      String
  lastName       String
  dob            DateTime
  guardianName   String?
  guardianEmail  String?
  waiverStatus   WaiverStatus @default(MISSING)
  eligibilityStatus EligibilityStatus @default(PENDING)
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt
}

enum WaiverStatus {
  MISSING
  SIGNED
}

enum EligibilityStatus {
  PENDING
  ELIGIBLE
  INELIGIBLE
  OVERRIDDEN
}

model LegalDocument {
  id        String   @id @default(cuid())
  type      LegalDocumentType
  version   String
  title     String
  body      String
  active    Boolean  @default(true)
  createdAt DateTime @default(now())
}

enum LegalDocumentType {
  WAIVER
  REFUND_POLICY
  TERMS
}

model LegalAcceptance {
  id               String   @id @default(cuid())
  legalDocumentId  String
  rosterEntryId    String?
  userId           String?
  signerName       String
  signerEmail      String?
  acceptedAt       DateTime @default(now())
  ipAddress        String?
  userAgent        String?
}

model PromoCode {
  id            String   @id @default(cuid())
  code          String   @unique
  discountType  PromoDiscountType
  amountCents   Int?
  percentOff    Int?
  maxUses       Int?
  usedCount     Int      @default(0)
  startsAt      DateTime?
  expiresAt     DateTime?
  active        Boolean  @default(true)
}

enum PromoDiscountType {
  FREE_ENTRY
  FIXED_AMOUNT
  PERCENT
}

model Payment {
  id                    String   @id @default(cuid())
  registrationId         String
  provider              PaymentProvider @default(STRIPE)
  stripeCheckoutSessionId String?
  stripePaymentIntentId  String?
  amountCents           Int
  status                PaymentStatus @default(PENDING)
  createdAt             DateTime @default(now())
  updatedAt             DateTime @updatedAt
}

enum PaymentProvider {
  STRIPE
}

enum PaymentStatus {
  PENDING
  SUCCEEDED
  FAILED
  REFUNDED
  COMPED
}

model Venue {
  id        String   @id @default(cuid())
  name      String
  address   String?
  latitude  Float?
  longitude Float?
}

model Field {
  id      String @id @default(cuid())
  venueId String
  name    String
}

model Game {
  id           String   @id @default(cuid())
  tournamentId String
  divisionId   String
  fieldId      String?
  homeTeamId   String?
  awayTeamId   String?
  startsAt     DateTime
  status       GameStatus @default(SCHEDULED)
  homeScore    Int?
  awayScore    Int?
  publishedAt  DateTime?
  updatedAt    DateTime @updatedAt
}

enum GameStatus {
  SCHEDULED
  IN_PROGRESS
  FINAL
  CANCELLED
  FORFEIT
}

model CheckIn {
  id             String   @id @default(cuid())
  tournamentId   String
  registrationId String?
  rosterEntryId  String?
  checkedInById  String?
  checkedInAt    DateTime @default(now())
  method         CheckInMethod @default(QR)
}

enum CheckInMethod {
  QR
  MANUAL
}
```

## 5. API Surface

Initial API groups:

- `GET /api/tournaments`
- `GET /api/tournaments/:slug`
- `GET /api/tournaments/:slug/schedule`
- `GET /api/tournaments/:slug/standings`
- `POST /api/registrations`
- `PATCH /api/registrations/:id`
- `POST /api/registrations/:id/roster`
- `POST /api/registrations/:id/promo-code`
- `POST /api/registrations/:id/checkout`
- `POST /api/stripe/webhook`
- `POST /api/legal/accept`
- `POST /api/check-in/qr`
- `POST /api/games/:id/score`

Organizer APIs should be protected by role-based authorization.

## 6. Auth And RBAC

MVP roles:

- Parent or guardian.
- Team Manager.
- Organizer.
- Admin.

Authorization rules:

- Public schedule and standings are readable without login after publication.
- Registration editing is limited to the team manager before organizer lock.
- Waiver acceptance belongs to guardian or authorized registration actor.
- Score reporting requires organizer or delegated coach permission.
- Schedule publishing and game changes require organizer/admin.

## 7. Stripe Integration

Payment flow:

1. Registration is created as draft.
2. User reviews roster and legal requirements.
3. Server creates Stripe Checkout Session.
4. Registration becomes `PENDING_PAYMENT`.
5. Stripe webhook receives payment success.
6. Payment becomes `SUCCEEDED`.
7. Registration becomes `PAID` or `READY` depending on roster, waiver, and eligibility.

Stripe webhook must be idempotent. Do not mark payment successful from the browser redirect alone.

## 8. Standings Calculation

When a game becomes final:

- Recalculate division standings.
- Store computed rows or compute on read for MVP.
- Default points: win 3, draw 1, loss 0.
- Default sorting: points, goal difference, goals for, team name.

## 9. Capacitor Integration

Native features:

- Push registration and token sync.
- QR scanner for check-in.
- Deep link handling for tournament, registration, game, and waiver links.
- Secure storage for app session metadata if needed.
- Share game or schedule links.
- Open maps app for venue navigation.

Capacitor should wrap the production web app route set while preserving app-specific entry points such as `/app/today` and `/my-games`.

## 10. Environment Variables

Required variables:

```text
DATABASE_URL=
NEXTAUTH_SECRET=
NEXTAUTH_URL=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
EMAIL_FROM=
RESEND_API_KEY=
NEXT_PUBLIC_APP_URL=
```

Mobile-specific values may include:

```text
NEXT_PUBLIC_IOS_BUNDLE_ID=
NEXT_PUBLIC_ANDROID_PACKAGE_ID=
```

## 11. Epic Plan

### Epic A - Foundation

- Initialize Next.js app with TypeScript.
- Add Prisma and PostgreSQL connection.
- Create base layout and routing.
- Add auth.
- Add RBAC helpers.
- Create initial schema migration.
- Seed one AAYSA Festival tournament.

### Epic B - Tournament Public Pages

- Tournament detail.
- Schedule.
- Teams.
- Standings.
- Venue.
- Rules and refund policy.

### Epic C - Registration

- Six-step registration wizard.
- Team manager profile.
- Team and division selection.
- Roster entry with DOB eligibility checks.
- Guardian and waiver collection.
- Review page.
- Promo code validation.

### Epic D - Payment

- Stripe Checkout.
- Stripe webhook.
- Payment status UI.
- Organizer payment review.

### Epic E - Organizer Console

- Registration table.
- Roster detail.
- Waiver status.
- Eligibility status.
- Manual status override.
- Venue, field, and schedule management.

### Epic F - Schedule And Results

- Game CRUD.
- Publish schedule.
- Score entry.
- Standings calculation.
- Change notifications.

### Epic G - Capacitor App

- Add Capacitor.
- Configure iOS and Android.
- App login handling.
- My Games view.
- Push notification token registration.
- QR check-in.
- Deep links.

## 12. Verification Checklist

Before using the first release for a real event:

- Registration can be completed on mobile.
- Promo code can reduce price, including free-entry code.
- Stripe webhook updates registration status.
- Incomplete waiver blocks ready status.
- Ineligible DOB is visible to organizer.
- Organizer can publish schedule.
- Public schedule renders without login.
- My Games shows the correct games after login.
- Schedule change produces notification record.
- QR check-in records staff/user and timestamp.
- Final score updates standings.

## 13. Implementation Principle

Keep the first release narrow and operational. The system should support one real tournament end to end before expanding into league management, SaaS multi-tenancy, automated scheduling, or advanced bracket features.
