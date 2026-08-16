import Link from "next/link";
import { getI18n } from "@/lib/i18n-server";
import { prisma } from "@/lib/prisma";

export default async function AccountPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const [registrations, rosterEntries, games] = await Promise.all([
    prisma.registration.count(),
    prisma.registrationRosterEntry.count(),
    prisma.game.count()
  ]);
  const copy =
    locale === "zh"
      ? {
          registrations: `当前工作区已有 ${registrations} 个报名。`,
          athletes: `已提交名单中共有 ${rosterEntries} 名球员。`,
          games: `赛事赛程中已有 ${games} 场比赛。`,
          open: "打开"
        }
      : {
          registrations: `${registrations} registrations connected in the current workspace.`,
          athletes: `${rosterEntries} athletes are currently on submitted rosters.`,
          games: `${games} games are available from tournament schedules.`,
          open: "Open"
        };

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.account}</div>
        <h1>{t.accountTitle}</h1>
        <p className="lead">{t.accountLead}</p>
      </section>

      <section className="grid">
        <article className="card">
          <h2>{t.teamsTitle}</h2>
          <p>{copy.registrations}</p>
          <Link className="text-link" href="/my-teams">
            {copy.open}
          </Link>
        </article>
        <article className="card">
          <h2>{t.athletesTitle}</h2>
          <p>{copy.athletes}</p>
          <Link className="text-link" href="/my-athletes">
            {copy.open}
          </Link>
        </article>
        <article className="card">
          <h2>{t.gamesTitle}</h2>
          <p>{copy.games}</p>
          <Link className="text-link" href="/my-games">
            {copy.open}
          </Link>
        </article>
      </section>
    </main>
  );
}
