import Link from "next/link";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { formatDateTime } from "@/lib/format";
import { labelStatus } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { prisma } from "@/lib/prisma";

export default async function WaiversPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const session = await getServerSession(authOptions);

  if (!session?.user?.id) {
    return (
      <main className="main">
        <section className="hero">
          <div className="eyebrow">{dictionary.common.account}</div>
          <h1>{t.waiversTitle}</h1>
          <p className="lead">{t.waiversLead}</p>
          <Link className="button" href="/auth/sign-in">
            {locale === "zh" ? "登录" : "Sign in"}
          </Link>
        </section>
      </main>
    );
  }

  const rosterEntries = await prisma.registrationRosterEntry.findMany({
    where: { registration: { managerUserId: session.user.id } },
    include: {
      legalAcceptances: {
        include: { legalDocument: true },
        orderBy: { acceptedAt: "desc" }
      },
      registration: {
        include: {
          team: true,
          tournament: true
        }
      }
    },
    orderBy: [{ waiverStatus: "asc" }, { lastName: "asc" }]
  });

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.account}</div>
        <h1>{t.waiversTitle}</h1>
        <p className="lead">{t.waiversLead}</p>
      </section>

      <section className="list-stack">
        {rosterEntries.map((entry) => {
          const acceptance = entry.legalAcceptances[0];

          return (
            <article className="row-card" key={entry.id}>
              <div>
                <span className={`status-pill ${entry.waiverStatus === "SIGNED" ? "ready" : "not-ready"}`}>
                  {labelStatus(entry.waiverStatus, locale)}
                </span>
                <h2>
                  {entry.firstName} {entry.lastName}
                </h2>
                <p>
                  {entry.registration.team?.name ?? dictionary.common.unassignedTeam} · {entry.registration.tournament.name}
                </p>
              </div>
              <div className="summary-strip">
                {acceptance ? <span>{formatDateTime(acceptance.acceptedAt, locale)}</span> : null}
                {acceptance?.legalDocument ? <span>{acceptance.legalDocument.version}</span> : null}
              </div>
            </article>
          );
        })}
      </section>
    </main>
  );
}
