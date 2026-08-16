import { notFound } from "next/navigation";
import { formatDateTime } from "@/lib/format";
import { labelStatus } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function SchedulePage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.schedule;
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{t.title}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.lead}</p>
      </section>

      <section className="list-stack">
        {tournament.games.map((game) => (
          <article className="row-card" key={game.id}>
            <div>
              <span className="step-label">{game.division.name}</span>
              <h2>
                {game.homeTeam?.name ?? dictionary.common.homeTbd} vs {game.awayTeam?.name ?? dictionary.common.awayTbd}
              </h2>
              <p>
                {formatDateTime(game.startsAt, locale)} · {game.field?.venue.name ?? dictionary.common.venueTbd} · {game.field?.name ?? dictionary.common.fieldTbd}
              </p>
            </div>
            <span className="status-pill">
              {game.status === "FINAL" ? `${game.homeScore}-${game.awayScore}` : labelStatus(game.status, locale)}
            </span>
          </article>
        ))}
      </section>
    </main>
  );
}
