import { NextRequest, NextResponse } from "next/server";
import { NotificationType, PaymentStatus } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { getRegistrationStatus, hasSuccessfulPayment } from "@/lib/registration";

const nextStatus = {
  comp: PaymentStatus.COMPED,
  received: PaymentStatus.SUCCEEDED,
  failed: PaymentStatus.FAILED,
  refunded: PaymentStatus.REFUNDED
} as const;

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const body = (await request.json()) as { action?: keyof typeof nextStatus };
  const status = body.action ? nextStatus[body.action] : null;

  if (!status) {
    return NextResponse.json({ error: "Invalid payment action" }, { status: 400 });
  }

  const registration = await prisma.registration.findUnique({
    where: { id },
    include: {
      division: true,
      rosterEntries: true,
      payments: { orderBy: { createdAt: "desc" } },
      team: true
    }
  });

  if (!registration) {
    return NextResponse.json({ error: "Registration not found" }, { status: 404 });
  }

  const updated = await prisma.$transaction(async (tx) => {
    if (registration.payments[0]) {
      await tx.payment.update({
        where: { id: registration.payments[0].id },
        data: { status }
      });
    } else {
      await tx.payment.create({
        data: {
          registrationId: registration.id,
          amountCents: registration.totalCents,
          status
        }
      });
    }

    const payments = await tx.payment.findMany({
      where: { registrationId: registration.id },
      orderBy: { createdAt: "desc" }
    });
    const registrationStatus = getRegistrationStatus({
      roster: registration.rosterEntries,
      division: registration.division,
      hasSuccessfulPayment: hasSuccessfulPayment(payments)
    });

    const nextRegistration = await tx.registration.update({
      where: { id: registration.id },
      data: { status: registrationStatus },
      include: { payments: { orderBy: { createdAt: "desc" } } }
    });

    await tx.notification.create({
      data: {
        tournamentId: registration.tournamentId,
        type: NotificationType.PAYMENT_CONFIRMATION,
        subject: "Payment status updated",
        body: `${registration.team?.name ?? "Registration"} marked ${status.toLowerCase()}`
      }
    });

    return nextRegistration;
  });

  return NextResponse.json({
    data: {
      id: updated.id,
      status: updated.status,
      paymentStatus: updated.payments[0]?.status ?? null
    }
  });
}
