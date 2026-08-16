import { formatDateTime } from "@/lib/format";
import { labelStatus } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export default async function AppTodayPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const games = await prisma.game.findMany({
    include: {
      tournament: true,
      field: { include: { venue: true } },
      homeTeam: true,
      awayTeam: true
    },
    orderBy: { startsAt: "asc" },
    take: 12
  });

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.mobileApp}</div>
        <h1>{t.todayTitle}</h1>
        <p className="lead">{t.todayLead}</p>
      </section>

      <section className="list-stack">
        {games.map((game) => (
          <article className="row-card" key={game.id}>
            <div>
              <span className="step-label">{game.tournament.name}</span>
              <h2>
                {game.homeTeam?.name ?? dictionary.common.homeTbd} vs {game.awayTeam?.name ?? dictionary.common.awayTbd}
              </h2>
              <p>
                {formatDateTime(game.startsAt, locale)} · {game.field?.venue.name ?? dictionary.common.venueTbd} · {game.field?.name ?? dictionary.common.fieldTbd}
              </p>
            </div>
            <span className="status-pill">{labelStatus(game.status, locale)}</span>
          </article>
        ))}
      </section>
    </main>
  );
}
