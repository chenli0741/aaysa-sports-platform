import Link from "next/link";
import { notFound } from "next/navigation";
import { formatDateRange, formatDateTime, formatMoney } from "@/lib/format";
import { interpolate, labelStatus, localizeFallback } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { TEAM_PRICE_CENTS } from "@/lib/registration";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function TournamentDetailPage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.tournamentDetail;
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{labelStatus(tournament.status, locale)}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{localizeFallback(tournament.description ?? "", locale)}</p>
        <div className="actions">
          <Link className="button" href={`/tournaments/${tournament.slug}/register`}>
            {t.registerTeam}
          </Link>
          <Link className="button secondary" href={`/tournaments/${tournament.slug}/schedule`}>
            {t.viewSchedule}
          </Link>
        </div>
      </section>

      <section className="feature-band">
        <div>
          <span className="step-label">{t.eventWindow}</span>
          <h2>{formatDateRange(tournament.startsAt, tournament.endsAt, locale)}</h2>
          <p>{interpolate(t.teamPrice, { price: formatMoney(TEAM_PRICE_CENTS, locale) })}</p>
        </div>
        <div className="summary-strip">
          <Link href={`/tournaments/${tournament.slug}/teams`}>{t.teams}</Link>
          <Link href={`/tournaments/${tournament.slug}/standings`}>{t.standings}</Link>
          <Link href={`/tournaments/${tournament.slug}/venue`}>{t.venue}</Link>
        </div>
      </section>

      <section className="grid">
        <article className="card">
          <h2>{t.divisions}</h2>
          {tournament.divisions.map((division) => (
            <p key={division.id}>
              {division.name}: {t.roster} {division.minRoster}-{division.maxRoster}
            </p>
          ))}
        </article>
        <article className="card">
          <h2>{t.sessions}</h2>
          {tournament.sessions.map((session) => (
            <p key={session.id}>
              {session.name}: {formatDateTime(session.startsAt, locale)}
            </p>
          ))}
        </article>
        <article className="card">
          <h2>{t.operations}</h2>
          <p>{interpolate(t.registrationsTracked, { count: tournament.registrations.length })}</p>
        </article>
      </section>
    </main>
  );
}
