# AAYSA Sports

Web-first tournament operations platform for AAYSA Sports.

The app is planned as a Next.js, TypeScript, Prisma, PostgreSQL, Stripe, and Capacitor project. The first release focuses on running one real tournament end to end: registration, payment, roster and waiver collection, scheduling, check-in, scores, and standings.

## Project

- Brand: AAYSA Sports
- App name: AAYSA Sports
- Repository: `aaysa-sports-platform`

## Getting Started

1. Install dependencies:

   ```bash
   nvm use
   npm install
   ```

2. Copy the environment template:

   ```bash
   cp .env.example .env.local
   ```

3. Set `DATABASE_URL` and service credentials in `.env.local`.

4. Generate Prisma client:

   ```bash
   npm run prisma:generate
   ```

5. Start the development server:

   ```bash
   npm run dev
   ```

## Scripts

- `npm run dev` starts the Next.js development server.
- `npm run build` creates a production build.
- `npm run start` starts the production server.
- `npm run lint` runs ESLint.
- `npm run typecheck` runs TypeScript checks.
- `npm run prisma:generate` generates the Prisma client.
- `npm run prisma:migrate` creates and applies a local Prisma migration.
- `npm run prisma:studio` opens Prisma Studio.

## Documentation

- [Product Requirements](docs/PRD.md)
- [Technical Specification](docs/TECH_SPEC.md)
