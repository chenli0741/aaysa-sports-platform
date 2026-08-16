import { formatDateTime } from "@/lib/format";
import { getI18n } from "@/lib/i18n-server";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function MyGamesPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const tournaments = await getTournaments();

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.account}</div>
        <h1>{t.gamesTitle}</h1>
        <p className="lead">{t.gamesLead}</p>
      </section>

      <section className="list-stack">
        {tournaments.map((tournament) =>
          tournament.sessions.slice(0, 4).map((session) => (
            <article className="row-card" key={session.id}>
              <div>
                <span className="step-label">{tournament.name}</span>
                <h2>{session.name}</h2>
                <p>{formatDateTime(session.startsAt, locale)}</p>
              </div>
            </article>
          ))
        )}
      </section>
    </main>
  );
}
