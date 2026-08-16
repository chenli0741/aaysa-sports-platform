import Link from "next/link";
import { formatDateRange } from "@/lib/format";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const tournaments = await getTournaments();
  const activeTournament = tournaments[0];

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">Tournament platform</div>
        <h1>AAYSA Sports</h1>
        <p className="lead">
          A web and mobile-supported operating system for tournament registration,
          rosters, waivers, schedules, check-in, score reporting, and standings.
        </p>
        <div className="actions">
          <Link className="button" href={activeTournament ? `/tournaments/${activeTournament.slug}` : "/tournaments"}>
            {activeTournament ? "Open active tournament" : "View tournaments"}
          </Link>
          <Link className="button secondary" href="/organizer">
            Organizer console
          </Link>
        </div>
      </section>

      {activeTournament ? (
        <section className="feature-band" aria-label="Active tournament">
          <div>
            <span className="step-label">Active event</span>
            <h2>{activeTournament.name}</h2>
            <p>{activeTournament.description}</p>
          </div>
          <div className="summary-strip">
            <span>{formatDateRange(activeTournament.startsAt, activeTournament.endsAt)}</span>
            <span>{activeTournament.divisions.length} divisions</span>
            <span>{activeTournament.registrations.length} registrations</span>
          </div>
        </section>
      ) : null}

      <section className="grid" aria-label="Platform areas">
        <article className="card">
          <h2>Registration</h2>
          <p>Team manager flow for division selection, rosters, waivers, promo codes, and Stripe payment.</p>
        </article>
        <article className="card">
          <h2>Event Operations</h2>
          <p>Organizer tools for registrations, schedule publishing, QR check-in, scores, and standings.</p>
        </article>
        <article className="card">
          <h2>Mobile Utility</h2>
          <p>Capacitor shell for app identity, stored sessions, push alerts, QR scanning, sharing, and deep links.</p>
        </article>
      </section>
    </main>
  );
}
