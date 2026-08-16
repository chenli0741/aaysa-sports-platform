import { notFound } from "next/navigation";
import { formatDateTime } from "@/lib/format";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function SchedulePage({
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
        <div className="eyebrow">Schedule</div>
        <h1>{tournament.name}</h1>
        <p className="lead">Published games, fields, opponents, and score status.</p>
      </section>

      <section className="list-stack">
        {tournament.games.map((game) => (
          <article className="row-card" key={game.id}>
            <div>
              <span className="step-label">{game.division.name}</span>
              <h2>
                {game.homeTeam?.name ?? "Home TBD"} vs {game.awayTeam?.name ?? "Away TBD"}
              </h2>
              <p>
                {formatDateTime(game.startsAt)} · {game.field?.venue.name ?? "Venue TBD"} · {game.field?.name ?? "Field TBD"}
              </p>
            </div>
            <span className="status-pill">
              {game.status === "FINAL" ? `${game.homeScore}-${game.awayScore}` : game.status.replaceAll("_", " ")}
            </span>
          </article>
        ))}
      </section>
    </main>
  );
}
