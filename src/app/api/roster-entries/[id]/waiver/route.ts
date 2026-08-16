import { NextRequest, NextResponse } from "next/server";
import { WaiverStatus } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { getRegistrationStatus, hasSuccessfulPayment } from "@/lib/registration";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const rosterEntry = await prisma.registrationRosterEntry.findUnique({
    where: { id },
    include: {
      registration: {
        include: {
          division: true,
          manager: true,
          payments: true,
          rosterEntries: true
        }
      }
    }
  });

  if (!rosterEntry) {
    return NextResponse.json({ error: "Roster entry not found" }, { status: 404 });
  }

  const activeWaiver = await prisma.legalDocument.findFirst({
    where: { type: "WAIVER", active: true },
    orderBy: { createdAt: "desc" }
  });
  const ipAddress = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;
  const userAgent = request.headers.get("user-agent");

  const updated = await prisma.$transaction(async (tx) => {
    await tx.registrationRosterEntry.update({
      where: { id },
      data: { waiverStatus: WaiverStatus.SIGNED }
    });

    if (activeWaiver) {
      const existing = await tx.legalAcceptance.findFirst({
        where: {
          legalDocumentId: activeWaiver.id,
          rosterEntryId: id
        }
      });

      if (!existing) {
        await tx.legalAcceptance.create({
          data: {
            legalDocumentId: activeWaiver.id,
            rosterEntryId: id,
            userId: rosterEntry.registration.managerUserId,
            signerName: rosterEntry.guardianName ?? rosterEntry.registration.manager?.name ?? "Guardian",
            signerEmail: rosterEntry.guardianEmail ?? rosterEntry.registration.manager?.email ?? null,
            ipAddress,
            userAgent
          }
        });
      }
    }

    const rosterEntries = rosterEntry.registration.rosterEntries.map((entry) =>
      entry.id === id ? { ...entry, waiverStatus: WaiverStatus.SIGNED } : entry
    );
    const registrationStatus = getRegistrationStatus({
      roster: rosterEntries,
      division: rosterEntry.registration.division,
      hasSuccessfulPayment: hasSuccessfulPayment(rosterEntry.registration.payments)
    });

    return tx.registration.update({
      where: { id: rosterEntry.registrationId },
      data: { status: registrationStatus }
    });
  });

  return NextResponse.json({
    data: {
      id,
      waiverStatus: WaiverStatus.SIGNED,
      registrationStatus: updated.status
    }
  });
}
