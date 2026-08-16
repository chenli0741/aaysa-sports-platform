import { NextRequest, NextResponse } from "next/server";
import {
  PaymentStatus,
  RegistrationStatus,
  UserRole,
  WaiverStatus,
  type Prisma
} from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { getRequestI18n } from "@/lib/i18n-request";
import { interpolate } from "@/lib/i18n";
import {
  PAYMENT_FEE_CENTS,
  RosterInput,
  TEAM_PRICE_CENTS,
  calculateEligibility,
  getRegistrationStatus
} from "@/lib/registration";

type RegistrationPayload = {
  tournamentSlug: string;
  managerName: string;
  managerEmail: string;
  managerPhone?: string;
  teamName: string;
  clubName?: string;
  divisionId: string;
  promoCode?: string;
  roster: RosterInput[];
};

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function requiredString(value: unknown) {
  return typeof value === "string" && value.trim().length > 0;
}

export async function POST(request: NextRequest) {
  const { dictionary } = getRequestI18n(request);
  const api = dictionary.apiErrors;
  const payload = (await request.json()) as RegistrationPayload;

  if (
    !requiredString(payload.tournamentSlug) ||
    !requiredString(payload.managerName) ||
    !requiredString(payload.managerEmail) ||
    !requiredString(payload.teamName) ||
    !requiredString(payload.divisionId)
  ) {
    return NextResponse.json({ error: api.missingRegistrationFields }, { status: 400 });
  }

  const roster = (payload.roster ?? []).filter(
    (entry) => requiredString(entry.firstName) && requiredString(entry.lastName) && requiredString(entry.dob)
  );

  const tournament = await prisma.tournament.findUnique({
    where: { slug: payload.tournamentSlug },
    include: { divisions: true }
  });

  if (!tournament) {
    return NextResponse.json({ error: api.tournamentNotFound }, { status: 404 });
  }

  const division = tournament.divisions.find((item) => item.id === payload.divisionId);

  if (!division) {
    return NextResponse.json({ error: api.divisionNotFound }, { status: 400 });
  }

  if (roster.length < division.minRoster || roster.length > division.maxRoster) {
    return NextResponse.json(
      { error: interpolate(api.rosterSize, { min: division.minRoster, max: division.maxRoster }) },
      { status: 400 }
    );
  }

  const promo = payload.promoCode
    ? await prisma.promoCode.findFirst({
        where: {
          code: payload.promoCode.trim().toUpperCase(),
          active: true,
          OR: [{ tournamentId: null }, { tournamentId: tournament.id }],
          AND: [
            { OR: [{ divisionId: null }, { divisionId: division.id }] },
            { OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] },
            { OR: [{ startsAt: null }, { startsAt: { lte: new Date() } }] }
          ]
        }
      })
    : null;

  let discountCents = 0;

  if (promo) {
    if (promo.discountType === "FREE_ENTRY") {
      discountCents = TEAM_PRICE_CENTS;
    } else if (promo.discountType === "FIXED_AMOUNT") {
      discountCents = Math.min(TEAM_PRICE_CENTS, promo.amountCents ?? 0);
    } else if (promo.discountType === "PERCENT") {
      discountCents = Math.round(TEAM_PRICE_CENTS * ((promo.percentOff ?? 0) / 100));
    }
  }

  const totalCents = Math.max(0, TEAM_PRICE_CENTS - discountCents + PAYMENT_FEE_CENTS);
  const email = normalizeEmail(payload.managerEmail);
  const activeWaiver = await prisma.legalDocument.findFirst({
    where: { type: "WAIVER", active: true },
    orderBy: { createdAt: "desc" }
  });
  const ipAddress = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;
  const userAgent = request.headers.get("user-agent");
  const rosterCreate: Prisma.RegistrationRosterEntryCreateWithoutRegistrationInput[] = roster.map((entry) => {
    const dob = new Date(entry.dob);

    return {
      firstName: entry.firstName.trim(),
      lastName: entry.lastName.trim(),
      dob,
      guardianName: entry.guardianName?.trim() || null,
      guardianEmail: entry.guardianEmail ? normalizeEmail(entry.guardianEmail) : null,
      waiverStatus: entry.waiverAccepted ? WaiverStatus.SIGNED : WaiverStatus.MISSING,
      eligibilityStatus: calculateEligibility(dob, division)
    };
  });

  const status = getRegistrationStatus({
    roster: rosterCreate.map((entry) => ({
      waiverStatus: entry.waiverStatus ?? WaiverStatus.MISSING,
      eligibilityStatus: entry.eligibilityStatus ?? "PENDING"
    })),
    division,
    hasSuccessfulPayment: totalCents === 0
  });

  const registration = await prisma.$transaction(async (tx) => {
    const manager = await tx.user.upsert({
      where: { email },
      update: {
        name: payload.managerName.trim(),
        phone: payload.managerPhone?.trim() || null,
        role: UserRole.TEAM_MANAGER
      },
      create: {
        email,
        name: payload.managerName.trim(),
        phone: payload.managerPhone?.trim() || null,
        role: UserRole.TEAM_MANAGER
      }
    });

    const club = payload.clubName?.trim()
      ? await tx.club.upsert({
          where: { name: payload.clubName.trim() },
          update: {},
          create: { name: payload.clubName.trim() }
        })
      : null;

    const team = await tx.team.create({
      data: {
        name: payload.teamName.trim(),
        clubId: club?.id
      }
    });

    const created = await tx.registration.create({
      data: {
        tournamentId: tournament.id,
        divisionId: division.id,
        teamId: team.id,
        managerUserId: manager.id,
        status,
        baseAmountCents: TEAM_PRICE_CENTS,
        discountCents,
        feeCents: PAYMENT_FEE_CENTS,
        totalCents,
        rosterEntries: { create: rosterCreate },
        payments: {
          create: {
            amountCents: totalCents,
            status: totalCents === 0 ? PaymentStatus.COMPED : PaymentStatus.PENDING
          }
        }
      },
      include: {
        team: true,
        division: true,
        rosterEntries: true,
        payments: true
      }
    });

    if (promo) {
      await tx.promoCode.update({
        where: { id: promo.id },
        data: { usedCount: { increment: 1 } }
      });
    }

    if (activeWaiver) {
      const signedEntries = created.rosterEntries.filter((entry) => entry.waiverStatus === WaiverStatus.SIGNED);

      if (signedEntries.length > 0) {
        await tx.legalAcceptance.createMany({
          data: signedEntries.map((entry) => ({
            legalDocumentId: activeWaiver.id,
            rosterEntryId: entry.id,
            userId: manager.id,
            signerName: entry.guardianName ?? payload.managerName.trim(),
            signerEmail: entry.guardianEmail ?? email,
            ipAddress,
            userAgent
          }))
        });
      }
    }

    return created;
  });

  return NextResponse.json(
    {
      data: {
        id: registration.id,
        status: registration.status,
        team: registration.team?.name,
        division: registration.division.name,
        totalCents: registration.totalCents,
        paymentStatus:
          registration.status === RegistrationStatus.READY ? "COMPED" : registration.payments[0]?.status
      }
    },
    { status: 201 }
  );
}
