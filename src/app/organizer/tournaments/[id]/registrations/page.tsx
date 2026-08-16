import { notFound } from "next/navigation";
import { RegistrationTable } from "@/components/registration-table";
import { getI18n } from "@/lib/i18n-server";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerRegistrationsPage({
  params
}: {
  params: Promise<{ id: string }>;
}) {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.organizer;
  const { id } = await params;
  const tournament = await getOrganizerTournament(id);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">{t.registrationsTitle}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.registrationsLead}</p>
      </section>

      <RegistrationTable
        registrations={tournament.registrations}
        locale={locale}
        labels={{ ...dictionary.table, ...dictionary.common }}
      />
    </main>
  );
}
