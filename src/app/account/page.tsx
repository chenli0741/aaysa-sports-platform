import Link from "next/link";
import { getServerSession } from "next-auth";
import { ProfileForm } from "@/components/auth-forms";
import { authOptions } from "@/lib/auth";
import { getI18n } from "@/lib/i18n-server";
import { prisma } from "@/lib/prisma";

export default async function AccountPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const session = await getServerSession(authOptions);

  if (!session?.user?.id) {
    const copy =
      locale === "zh"
        ? {
            title: "账户",
            lead: "登录后可以查看你的队伍、球员、比赛和免责声明。",
            signIn: "登录",
            signUp: "创建账户"
          }
        : {
            title: "Account",
            lead: "Sign in to view your teams, athletes, games, and waivers.",
            signIn: "Sign in",
            signUp: "Create account"
          };

    return (
      <main className="main">
        <section className="hero">
          <div className="eyebrow">{dictionary.common.account}</div>
          <h1>{copy.title}</h1>
          <p className="lead">{copy.lead}</p>
          <div className="actions">
            <Link className="button" href="/auth/sign-in">
              {copy.signIn}
            </Link>
            <Link className="button secondary" href="/auth/sign-up">
              {copy.signUp}
            </Link>
          </div>
        </section>
      </main>
    );
  }

  const [registrations, rosterEntries, games] = await Promise.all([
    prisma.registration.findMany({
      where: { managerUserId: session.user.id },
      include: { team: true, rosterEntries: true }
    }),
    prisma.registrationRosterEntry.count({
      where: { registration: { managerUserId: session.user.id } }
    }),
    prisma.game.count({
      where: {
        OR: [
          { homeTeam: { registrations: { some: { managerUserId: session.user.id } } } },
          { awayTeam: { registrations: { some: { managerUserId: session.user.id } } } }
        ]
      }
    })
  ]);
  const user = await prisma.user.findUnique({ where: { id: session.user.id } });
  const copy =
    locale === "zh"
      ? {
          registrations: `你的账户下有 ${registrations.length} 个报名。`,
          athletes: `已提交名单中共有 ${rosterEntries} 名球员。`,
          games: `你的队伍关联到 ${games} 场比赛。`,
          open: "打开",
          profile: "个人资料"
        }
      : {
          registrations: `${registrations.length} registrations are connected to your account.`,
          athletes: `${rosterEntries} athletes are currently on submitted rosters.`,
          games: `${games} games are linked to your teams.`,
          open: "Open",
          profile: "Profile"
        };

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.account}</div>
        <h1>{t.accountTitle}</h1>
        <p className="lead">{t.accountLead}</p>
      </section>

      <section className="form-section auth-section">
        <div>
          <span className="step-label">{copy.profile}</span>
          <h2>{user?.email ?? session.user.email}</h2>
        </div>
        <ProfileForm locale={locale} initialName={user?.name ?? ""} initialPhone={user?.phone ?? ""} />
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
