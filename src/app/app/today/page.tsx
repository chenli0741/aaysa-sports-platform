import { formatDateTime } from "@/lib/format";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function AppTodayPage() {
  const tournaments = await getTournaments();

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">Mobile app</div>
        <h1>Today</h1>
        <p className="lead">Event-day app entry for games, venues, check-in, alerts, and sharing.</p>
      </section>

      <section className="list-stack">
        {tournaments.flatMap((tournament) =>
          tournament.sessions.map((session) => (
            <article className="row-card" key={session.id}>
              <div>
                <span className="step-label">{tournament.name}</span>
                <h2>{session.name}</h2>
                <p>{formatDateTime(session.startsAt)}</p>
              </div>
            </article>
          ))
        )}
      </section>
    </main>
  );
}
