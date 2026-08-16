import type { Division, Payment, RegistrationRosterEntry } from "@prisma/client";
import { labelStatus, type Locale } from "@/lib/i18n";
import { summarizeReadiness } from "@/lib/registration";

type RegistrationRow = {
  id: string;
  status: string;
  team: { name: string; club?: { name: string } | null } | null;
  division: Division;
  rosterEntries: RegistrationRosterEntry[];
  payments: Payment[];
};

export function RegistrationTable({
  registrations,
  locale,
  labels
}: {
  registrations: RegistrationRow[];
  locale: Locale;
  labels: {
    noRegistrations: string;
    team: string;
    division: string;
    roster: string;
    payment: string;
    waivers: string;
    eligibility: string;
    status: string;
    ready: string;
    unassignedTeam: string;
    independent: string;
  };
}) {
  if (registrations.length === 0) {
    return <p className="empty-state">{labels.noRegistrations}</p>;
  }

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>{labels.team}</th>
            <th>{labels.division}</th>
            <th>{labels.roster}</th>
            <th>{labels.payment}</th>
            <th>{labels.waivers}</th>
            <th>{labels.eligibility}</th>
            <th>{labels.status}</th>
          </tr>
        </thead>
        <tbody>
          {registrations.map((registration) => {
            const summary = summarizeReadiness({
              roster: registration.rosterEntries,
              division: registration.division,
              payments: registration.payments,
              locale
            });

            return (
              <tr key={registration.id}>
                <td>
                  <strong>{registration.team?.name ?? labels.unassignedTeam}</strong>
                  <span>{registration.team?.club?.name ?? labels.independent}</span>
                </td>
                <td>{registration.division.name}</td>
                <td>{summary.roster}</td>
                <td>{summary.payment}</td>
                <td>{summary.waivers}</td>
                <td>{summary.eligibility}</td>
                <td>
                  <span className={`status-pill ${summary.ready ? "ready" : "not-ready"}`}>
                    {summary.ready ? labels.ready : labelStatus(registration.status, locale)}
                  </span>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
