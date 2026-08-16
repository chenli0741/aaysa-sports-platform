import Link from "next/link";
import { notFound } from "next/navigation";
import { formatDateRange } from "@/lib/format";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerTournamentPage({
  params
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const tournament = await getOrganizerTournament(id);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">Organizer</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{formatDateRange(tournament.startsAt, tournament.endsAt)}</p>
      </section>

      <section className="grid">
        <article className="card">
          <h2>Registrations</h2>
          <p>{tournament.registrations.length} registrations tracked.</p>
          <Link className="text-link" href={`/organizer/tournaments/${tournament.id}/registrations`}>
            Review registrations
          </Link>
        </article>
        <article className="card">
          <h2>Schedule</h2>
          <p>{tournament.games.length} games configured.</p>
          <Link className="text-link" href={`/organizer/tournaments/${tournament.id}/schedule`}>
            Manage schedule
          </Link>
        </article>
        <article className="card">
          <h2>Event day</h2>
          <p>Check-in, score reporting, and standings tools.</p>
          <Link className="text-link" href={`/organizer/tournaments/${tournament.id}/check-in`}>
            Open check-in
          </Link>
        </article>
      </section>

      <section className="feature-band">
        <div>
          <span className="step-label">Notifications</span>
          <h2>Recent activity</h2>
        </div>
        <div className="summary-strip">
          <Link href={`/organizer/tournaments/${tournament.id}/scores`}>Scores</Link>
          <Link href={`/organizer/tournaments/${tournament.id}/standings`}>Standings</Link>
        </div>
      </section>
    </main>
  );
}
