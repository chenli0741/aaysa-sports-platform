import { notFound } from "next/navigation";
import { ScoreForm } from "@/components/score-form";
import { formatDateTime } from "@/lib/format";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function ScoresPage({
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
        <div className="eyebrow">Scores</div>
        <h1>{tournament.name}</h1>
        <p className="lead">Enter final scores. Saving a score updates standings and records a score notification.</p>
      </section>

      <section className="list-stack">
        {tournament.games.map((game) => (
          <article className="row-card" key={game.id}>
            <div>
              <span className="step-label">{formatDateTime(game.startsAt)}</span>
              <h2>
                {game.homeTeam?.name ?? "Home TBD"} vs {game.awayTeam?.name ?? "Away TBD"}
              </h2>
              <p>{game.status === "FINAL" ? `Final ${game.homeScore}-${game.awayScore}` : game.status}</p>
            </div>
            <ScoreForm gameId={game.id} />
          </article>
        ))}
      </section>
    </main>
  );
}
