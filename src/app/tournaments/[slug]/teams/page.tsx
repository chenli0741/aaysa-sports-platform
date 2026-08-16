import { notFound } from "next/navigation";
import { RegistrationTable } from "@/components/registration-table";
import { getI18n } from "@/lib/i18n-server";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function TeamsPage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.teams;
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">{t.title}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.lead}</p>
      </section>

      <RegistrationTable
        registrations={tournament.registrations}
        locale={locale}
        labels={{ ...dictionary.table, ...dictionary.common }}
      />
    </main>
  );
}
