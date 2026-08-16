import Link from "next/link";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerPage() {
  const tournaments = await getTournaments();

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">Operations</div>
        <h1>Organizer</h1>
        <p className="lead">Registration readiness, schedule management, check-in, scores, and standings.</p>
      </section>

      <section className="grid" aria-label="Organizer actions">
        <article className="card">
          <h2>Tournaments</h2>
          <p>Review event setup, sessions, venues, registrations, and operational status.</p>
          <Link className="text-link" href="/organizer/tournaments">
            View tournaments
          </Link>
        </article>
        <article className="card">
          <h2>Registrations</h2>
          <p>Track roster counts, payment status, waiver completion, and eligibility readiness.</p>
        </article>
        <article className="card">
          <h2>Event day</h2>
          <p>Publish schedules, check teams in, enter scores, and update standings.</p>
        </article>
      </section>

      <section className="list-stack">
        {tournaments.map((tournament) => (
          <article className="row-card" key={tournament.id}>
            <div>
              <span className="step-label">Current event</span>
              <h2>{tournament.name}</h2>
              <p>{tournament.registrations.length} registrations</p>
            </div>
            <Link className="button secondary" href={`/organizer/tournaments/${tournament.id}`}>
              Manage
            </Link>
          </article>
        ))}
      </section>
    </main>
  );
}
