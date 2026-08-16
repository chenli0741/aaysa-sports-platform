import { notFound } from "next/navigation";
import { formatDateTime } from "@/lib/format";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerSchedulePage({
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
        <div className="eyebrow">Organizer schedule</div>
        <h1>{tournament.name}</h1>
        <p className="lead">Published games and field assignments.</p>
      </section>

      <section className="list-stack">
        {tournament.games.map((game) => (
          <article className="row-card" key={game.id}>
            <div>
              <span className="step-label">{game.status.replaceAll("_", " ")}</span>
              <h2>
                {game.homeTeam?.name ?? "Home TBD"} vs {game.awayTeam?.name ?? "Away TBD"}
              </h2>
              <p>
                {formatDateTime(game.startsAt)} · {game.field?.venue.name ?? "Venue TBD"} · {game.field?.name ?? "Field TBD"}
              </p>
            </div>
          </article>
        ))}
      </section>
    </main>
  );
}
