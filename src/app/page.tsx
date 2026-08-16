import Link from "next/link";
import { formatDateRange } from "@/lib/format";
import { getI18n } from "@/lib/i18n-server";
import { localizeFallback } from "@/lib/i18n";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.home;
  const tournaments = await getTournaments();
  const activeTournament = tournaments[0];

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{t.eyebrow}</div>
        <h1>AAYSA Sports</h1>
        <p className="lead">{t.lead}</p>
        <div className="actions">
          <Link className="button" href={activeTournament ? `/tournaments/${activeTournament.slug}` : "/tournaments"}>
            {activeTournament ? t.openActive : t.viewTournaments}
          </Link>
          <Link className="button secondary" href="/organizer">
            {t.organizerConsole}
          </Link>
        </div>
      </section>

      {activeTournament ? (
        <section className="feature-band" aria-label={t.activeEvent}>
          <div>
            <span className="step-label">{t.activeEvent}</span>
            <h2>{activeTournament.name}</h2>
            <p>{localizeFallback(activeTournament.description ?? "", locale)}</p>
          </div>
          <div className="summary-strip">
            <span>{formatDateRange(activeTournament.startsAt, activeTournament.endsAt, locale)}</span>
            <span>{activeTournament.divisions.length} {t.divisions}</span>
            <span>{activeTournament.registrations.length} {t.registrations}</span>
          </div>
        </section>
      ) : null}

      <section className="grid" aria-label={t.areas}>
        <article className="card">
          <h2>{t.registrationTitle}</h2>
          <p>{t.registrationBody}</p>
        </article>
        <article className="card">
          <h2>{t.operationsTitle}</h2>
          <p>{t.operationsBody}</p>
        </article>
        <article className="card">
          <h2>{t.mobileTitle}</h2>
          <p>{t.mobileBody}</p>
        </article>
      </section>
    </main>
  );
}
