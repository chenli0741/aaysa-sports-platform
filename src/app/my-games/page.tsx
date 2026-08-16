import Link from "next/link";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { formatDateTime } from "@/lib/format";
import { labelStatus } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export default async function MyGamesPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const session = await getServerSession(authOptions);

  if (!session?.user?.id) {
    return (
      <main className="main">
        <section className="hero">
          <div className="eyebrow">{dictionary.common.account}</div>
          <h1>{t.gamesTitle}</h1>
          <p className="lead">{t.gamesLead}</p>
          <Link className="button" href="/auth/sign-in">
            {locale === "zh" ? "登录" : "Sign in"}
          </Link>
        </section>
      </main>
    );
  }

  const games = await prisma.game.findMany({
    where: {
      OR: [
        { homeTeam: { registrations: { some: { managerUserId: session.user.id } } } },
        { awayTeam: { registrations: { some: { managerUserId: session.user.id } } } }
      ]
    },
    include: {
      tournament: true,
      field: { include: { venue: true } },
      homeTeam: true,
      awayTeam: true
    },
    orderBy: { startsAt: "asc" }
  });

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.account}</div>
        <h1>{t.gamesTitle}</h1>
        <p className="lead">{t.gamesLead}</p>
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
