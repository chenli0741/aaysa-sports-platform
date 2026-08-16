import Link from "next/link";
import { formatDateRange } from "@/lib/format";
import { labelStatus, localizeFallback } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function TournamentsPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.tournaments;
  const tournaments = await getTournaments();

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.public}</div>
        <h1>{t.title}</h1>
        <p className="lead">{t.lead}</p>
      </section>

      <section className="list-stack">
        {tournaments.map((tournament) => (
          <article className="row-card" key={tournament.id}>
            <div>
              <span className="status-pill">{labelStatus(tournament.status, locale)}</span>
              <h2>{tournament.name}</h2>
              <p>{localizeFallback(tournament.description ?? "", locale)}</p>
              <div className="summary-strip compact">
                <span>{formatDateRange(tournament.startsAt, tournament.endsAt, locale)}</span>
                <span>{tournament.sessions.length} {t.sessions}</span>
                <span>{tournament.divisions.length} {dictionary.home.divisions}</span>
              </div>
            </div>
            <Link className="button secondary" href={`/tournaments/${tournament.slug}`}>
              {dictionary.common.open}
            </Link>
          </article>
        ))}
      </section>
    </main>
  );
}
