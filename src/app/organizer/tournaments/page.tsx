import Link from "next/link";
import { formatDateRange } from "@/lib/format";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerTournamentsPage() {
  const tournaments = await getTournaments();

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">Organizer</div>
        <h1>Tournaments</h1>
        <p className="lead">Event setup and operating status.</p>
      </section>

      <section className="list-stack">
        {tournaments.map((tournament) => (
          <article className="row-card" key={tournament.id}>
            <div>
              <span className="status-pill">{tournament.status.replaceAll("_", " ")}</span>
              <h2>{tournament.name}</h2>
              <p>{formatDateRange(tournament.startsAt, tournament.endsAt)}</p>
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
