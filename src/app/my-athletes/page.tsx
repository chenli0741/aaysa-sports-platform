import { formatDate } from "@/lib/format";
import { labelStatus } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { prisma } from "@/lib/prisma";

export default async function MyAthletesPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const rosterEntries = await prisma.registrationRosterEntry.findMany({
    include: {
      registration: {
        include: {
          tournament: true,
          team: true,
          division: true
        }
      }
    },
    orderBy: [{ lastName: "asc" }, { firstName: "asc" }]
  });

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.account}</div>
        <h1>{t.athletesTitle}</h1>
        <p className="lead">{t.athletesLead}</p>
      </section>

      <section className="grid">
        {rosterEntries.map((entry) => (
          <article className="card" key={entry.id}>
            <h2>
              {entry.firstName} {entry.lastName}
            </h2>
            <p>{formatDate(entry.dob, locale)}</p>
            <p>
              {entry.registration.team?.name ?? dictionary.common.unassignedTeam} · {entry.registration.division.name}
            </p>
            <div className="summary-strip compact">
              <span>{labelStatus(entry.waiverStatus, locale)}</span>
              <span>{labelStatus(entry.eligibilityStatus, locale)}</span>
            </div>
          </article>
        ))}
      </section>
    </main>
  );
}
