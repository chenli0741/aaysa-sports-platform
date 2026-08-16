import Link from "next/link";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { formatMoney } from "@/lib/format";
import { labelStatus } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { prisma } from "@/lib/prisma";

export default async function MyTeamsPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const session = await getServerSession(authOptions);

  if (!session?.user?.id) {
    return (
      <main className="main">
        <section className="hero">
          <div className="eyebrow">{dictionary.common.account}</div>
          <h1>{t.teamsTitle}</h1>
          <p className="lead">{t.teamsLead}</p>
          <Link className="button" href="/auth/sign-in">
            {locale === "zh" ? "登录" : "Sign in"}
          </Link>
        </section>
      </main>
    );
  }

  const registrations = await prisma.registration.findMany({
    where: { managerUserId: session.user.id },
    include: {
      tournament: true,
      team: { include: { club: true } },
      division: true,
      rosterEntries: true,
      payments: { orderBy: { createdAt: "desc" } }
    },
    orderBy: { createdAt: "desc" }
  });

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.account}</div>
        <h1>{t.teamsTitle}</h1>
        <p className="lead">{t.teamsLead}</p>
      </section>

      <section className="list-stack">
        {registrations.map((registration) => (
          <article className="row-card" key={registration.id}>
            <div>
              <span className="step-label">{registration.tournament.name}</span>
              <h2>{registration.team?.name ?? dictionary.common.unassignedTeam}</h2>
              <p>
                {registration.division.name} · {registration.rosterEntries.length} players ·{" "}
                {formatMoney(registration.totalCents, locale)}
              </p>
            </div>
            <div className="summary-strip">
              <span>{labelStatus(registration.status, locale)}</span>
              <Link className="button secondary" href={`/tournaments/${registration.tournament.slug}/teams`}>
                {dictionary.tournamentDetail.teams}
              </Link>
            </div>
          </article>
        ))}
      </section>
    </main>
  );
}
