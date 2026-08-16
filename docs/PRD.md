# AAYSA Tournament Platform PRD

Version: v0.2
Date: 2026-08-16

## 1. Product Goal

AAYSA needs a web and mobile-supported sports tournament platform for running real youth club events. The first release should not be a marketing-only site. It must support the full operating path for a real event:

Create tournament -> create divisions -> team registration -> Stripe payment -> roster collection -> venue and field setup -> schedule publishing -> My Games -> push change alerts -> QR check-in -> score reporting -> automatic standings.

The product will be built web-first and wrapped for iOS/Android with Capacitor. Web and app share the core UI. Capacitor is used only for native phone capabilities such as push notifications, QR/camera, deep links, secure storage, maps, and sharing.

## 2. Reference Event

The v0.2 requirements include business rules observed from the AAYSA Festival signup reference page:

- Team Manager completes team registration.
- Format: 5v5.
- Roster size: 5 to 7 players per team.
- Division eligibility is determined by player date of birth.
- Team price: USD 380 per team.
- Promo code support is required.
- Payment processing fee support is required.
- Each player guardian must separately accept the waiver.
- Players with missing waiver acceptance are not eligible to participate.
- One registration may include multiple event sessions, such as Sunday sessions on August 2, 9, 16, and 23, 2026.

The product should improve on the reference signup UX by replacing the long single-page form with a structured mobile-friendly registration flow.

## 3. Target Users

- Public visitor: views event info, schedule, standings, venues, rules, sponsors.
- Parent or guardian: signs waiver, views athlete schedule, receives changes.
- Team Manager or coach: registers team, maintains roster, views games, reports scores where permitted.
- Organizer staff: creates events, reviews registrations, publishes schedules, checks teams in, manages results.
- Platform admin: manages users, roles, payments, event configuration, and global settings.

## 4. MVP Scope

### Public Website

- Home page with active tournament entry points.
- Tournament detail page.
- Registration entry.
- Schedule.
- Teams.
- Standings and results.
- Venue and field map.
- Rules and refund policy.
- Sponsors.

### Registration Flow

The first release registration flow should be:

1. Team Manager
2. Team and Division
3. Roster
4. Guardian and Waiver
5. Review and Promo
6. Payment

Required registration fields:

- Team Manager name, email, phone.
- Team name.
- Club or organization name, optional for independent teams.
- Division.
- Player first name, last name, date of birth.
- Guardian name and contact information.
- Waiver acceptance per player.
- Promo code.
- Payment details through Stripe Checkout.

Registration statuses:

- Draft
- Pending Payment
- Paid
- Waiver Incomplete
- Eligibility Review
- Ready
- Cancelled
- Refunded

Organizer list view must show:

```text
Team
Division
Roster
Payment
Waivers
Eligibility
Status
```

Example:

```text
Dragons U11
Roster 7/7
Paid
Waivers 5/7
NOT READY
```

### Tournament Operations

- Create event and divisions.
- Configure sessions, dates, venues, and fields.
- Approve or flag registrations.
- Build or import schedules.
- Publish schedules.
- Edit game time, field, or opponent.
- Send change notifications.
- QR check-in for teams or players.
- Enter final scores.
- Auto-calculate standings.

### Mobile App Shell

The mobile app should focus on event-day utility:

- Login and stored session.
- Today view.
- My Games.
- Field and navigation.
- QR check-in.
- Push notifications for schedule changes.
- Native share.
- Deep links from emails or notifications.

## 5. Core Pages

### Public

- `/`
- `/tournaments`
- `/tournaments/[slug]`
- `/tournaments/[slug]/register`
- `/tournaments/[slug]/schedule`
- `/tournaments/[slug]/teams`
- `/tournaments/[slug]/standings`
- `/tournaments/[slug]/venue`
- `/rules`

### Authenticated User

- `/account`
- `/my-athletes`
- `/my-teams`
- `/my-games`
- `/waivers`

### Organizer

- `/organizer`
- `/organizer/tournaments`
- `/organizer/tournaments/[id]`
- `/organizer/tournaments/[id]/registrations`
- `/organizer/tournaments/[id]/schedule`
- `/organizer/tournaments/[id]/check-in`
- `/organizer/tournaments/[id]/scores`
- `/organizer/tournaments/[id]/standings`

## 6. Business Rules

### Division Eligibility

- A division defines allowed birth date range.
- Each roster entry stores DOB.
- Eligibility is calculated per player.
- Team readiness requires roster size within limits and all players eligible or approved.

### Roster

- 5v5 event requires 5 to 7 players.
- Teams below minimum are not ready.
- Teams above maximum cannot submit unless organizer overrides.
- Roster changes after schedule publication should be logged.

### Waiver

- Waiver is not just a checkbox.
- Store legal document version.
- Store signer identity.
- Store player association.
- Store timestamp and IP/user-agent when available.
- Missing waiver means player cannot participate.

### Promo Code

Supported discount types:

- `FREE_ENTRY`
- `FIXED_AMOUNT`
- `PERCENT`

Promo code rules may include:

- Event scope.
- Division scope.
- Usage limit.
- Per-team or global limit.
- Expiration.
- Eligibility note, such as returning team promotion.

### Payment

- Stripe is the payment provider.
- Registration is not ready until payment succeeds or organizer marks comped.
- Stripe webhook is source of truth for successful payment.
- Refund state must be visible to organizer.

### Standings

Default standings fields:

- Games played.
- Wins.
- Draws.
- Losses.
- Goals for.
- Goals against.
- Goal difference.
- Points.

Default points:

- Win: 3
- Draw: 1
- Loss: 0

Tie-breakers should be configurable later. MVP may use points, goal difference, goals for, then team name.

## 7. Notification Requirements

Send notifications for:

- Registration payment confirmation.
- Waiver missing reminder.
- Schedule published.
- Game time change.
- Field change.
- Score finalized.

Channels:

- Email for MVP.
- Push notifications for app users.
- SMS optional later.

## 8. Non-Goals For MVP

- Full league season management.
- Complex referee assignment.
- Automated schedule optimization.
- Multi-tenant SaaS billing.
- Team chat.
- Advanced bracket generator.
- Wearables, Bluetooth devices, or live GPS staff tracking.

## 9. Success Criteria

The first release is successful when AAYSA can run one real tournament without spreadsheets as the main source of truth:

- Teams can register and pay.
- Rosters and waivers are visible.
- Organizer can identify not-ready teams.
- Schedule can be published.
- Families can see their games.
- Schedule changes can be communicated.
- Staff can check teams in.
- Scores produce standings.

## 10. Development Starting Point

Start with Epic A in the technical spec:

1. Initialize Next.js app.
2. Configure PostgreSQL and Prisma.
3. Implement Auth and RBAC.
4. Create first database migration.
5. Build tournament and registration foundation.
