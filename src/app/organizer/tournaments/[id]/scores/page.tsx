import { notFound } from "next/navigation";
import { ScoreForm } from "@/components/score-form";
import { formatDateTime } from "@/lib/format";
import { labelStatus } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function ScoresPage({
  params
}: {
  params: Promise<{ id: string }>;
}) {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.organizer;
  const { id } = await params;
  const tournament = await getOrganizerTournament(id);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{t.scores}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.scoresLead}</p>
      </section>

      <section className="list-stack">
        {tournament.games.map((game) => (
          <article className="row-card" key={game.id}>
            <div>
              <span className="step-label">{formatDateTime(game.startsAt, locale)}</span>
              <h2>
                {game.homeTeam?.name ?? dictionary.common.homeTbd} vs {game.awayTeam?.name ?? dictionary.common.awayTbd}
              </h2>
              <p>
                {game.status === "FINAL"
                  ? `${dictionary.common.final} ${game.homeScore}-${game.awayScore}`
                  : labelStatus(game.status, locale)}
              </p>
            </div>
            <ScoreForm gameId={game.id} locale={locale} />
          </article>
        ))}
      </section>
    </main>
  );
}
