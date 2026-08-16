import type { Division, Payment, RegistrationRosterEntry } from "@prisma/client";
import { summarizeReadiness } from "@/lib/registration";

type RegistrationRow = {
  id: string;
  status: string;
  team: { name: string; club?: { name: string } | null } | null;
  division: Division;
  rosterEntries: RegistrationRosterEntry[];
  payments: Payment[];
};

export function RegistrationTable({ registrations }: { registrations: RegistrationRow[] }) {
  if (registrations.length === 0) {
    return <p className="empty-state">No registrations yet.</p>;
  }

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Team</th>
            <th>Division</th>
            <th>Roster</th>
            <th>Payment</th>
            <th>Waivers</th>
            <th>Eligibility</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {registrations.map((registration) => {
            const summary = summarizeReadiness({
              roster: registration.rosterEntries,
              division: registration.division,
              payments: registration.payments
            });

            return (
              <tr key={registration.id}>
                <td>
                  <strong>{registration.team?.name ?? "Unassigned team"}</strong>
                  <span>{registration.team?.club?.name ?? "Independent"}</span>
                </td>
                <td>{registration.division.name}</td>
                <td>{summary.roster}</td>
                <td>{summary.payment}</td>
                <td>{summary.waivers}</td>
                <td>{summary.eligibility}</td>
                <td>
                  <span className={`status-pill ${summary.ready ? "ready" : "not-ready"}`}>
                    {summary.ready ? "READY" : registration.status.replaceAll("_", " ")}
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
