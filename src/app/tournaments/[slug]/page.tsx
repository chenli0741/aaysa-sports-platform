import Link from "next/link";
import { notFound } from "next/navigation";
import { formatDateRange, formatDateTime, formatMoney } from "@/lib/format";
import { TEAM_PRICE_CENTS } from "@/lib/registration";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function TournamentDetailPage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{tournament.status.replaceAll("_", " ")}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{tournament.description}</p>
        <div className="actions">
          <Link className="button" href={`/tournaments/${tournament.slug}/register`}>
            Register team
          </Link>
          <Link className="button secondary" href={`/tournaments/${tournament.slug}/schedule`}>
            View schedule
          </Link>
        </div>
      </section>

      <section className="feature-band">
        <div>
          <span className="step-label">Event window</span>
          <h2>{formatDateRange(tournament.startsAt, tournament.endsAt)}</h2>
          <p>Team price starts at {formatMoney(TEAM_PRICE_CENTS)} before promo codes and processing fees.</p>
        </div>
        <div className="summary-strip">
          <Link href={`/tournaments/${tournament.slug}/teams`}>Teams</Link>
          <Link href={`/tournaments/${tournament.slug}/standings`}>Standings</Link>
          <Link href={`/tournaments/${tournament.slug}/venue`}>Venue</Link>
        </div>
      </section>

      <section className="grid">
        <article className="card">
          <h2>Divisions</h2>
          {tournament.divisions.map((division) => (
            <p key={division.id}>
              {division.name}: roster {division.minRoster}-{division.maxRoster}
            </p>
          ))}
        </article>
        <article className="card">
          <h2>Sessions</h2>
          {tournament.sessions.map((session) => (
            <p key={session.id}>
              {session.name}: {formatDateTime(session.startsAt)}
            </p>
          ))}
        </article>
        <article className="card">
          <h2>Operations</h2>
          <p>{tournament.registrations.length} team registrations are currently tracked for this event.</p>
        </article>
      </section>
    </main>
  );
}
