import { prisma } from '../prisma';
import { generateInviteCode } from '../utils/inviteCode';
import { unitService } from './unitService';

const INVITE_CODE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export const businessService = {
  async create(ownerId: string, name: string) {
    // No invite code generated here anymore — codes are ephemeral,
    // generated on demand when the owner taps "Share" (generateInviteCode
    // below), not a permanent business attribute.
    const business = await prisma.business.create({
      data: {
        name,
        ownerId,
        members: {
          create: { userId: ownerId, role: 'owner' },
        },
      },
    });

    await unitService.ensureDefaultUnitsLinked(business.id);

    return business;
  },

  /**
   * Generates a fresh OTP-style invite code: valid 5 minutes, single-use.
   * A separate row per code (invite_codes table) — multiple codes can be
   * concurrently valid for the same business (e.g. one per new hire);
   * generating a new one does NOT invalidate any others still outstanding.
   */
  async generateInviteCode(businessId: string, createdBy: string) {
    // Retry a few times on the (astronomically unlikely) event of a
    // collision with another still-active code's random string.
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = generateInviteCode();
      const expiresAt = new Date(Date.now() + INVITE_CODE_TTL_MS);
      try {
        await prisma.inviteCode.create({
          data: { businessId, code, expiresAt, createdBy },
        });
        return { code, expiresAt };
      } catch (err: any) {
        if (err.code === 'P2002') continue; // unique constraint on code — retry
        throw err;
      }
    }
    throw new Error('Failed to generate a unique invite code');
  },

  async joinByCode(userId: string, code: string) {
    const invite = await prisma.inviteCode.findFirst({
      where: {
        code: code.toUpperCase(),
        expiresAt: { gt: new Date() },
        usedAt: null,
      },
    });

    // Deliberately one generic message for "not found" / "expired" /
    // "already used" — design.md rule 11: one plain sentence, don't make
    // the user parse different failure reasons.
    if (!invite) {
      throw new Error('CODE_NOT_FOUND');
    }

    const business = await prisma.business.findUnique({
      where: { id: invite.businessId },
    });
    if (!business) {
      throw new Error('CODE_NOT_FOUND');
    }

    const existing = await prisma.businessMember.findUnique({
      where: { businessId_userId: { businessId: business.id, userId } },
    });
    if (existing) {
      return business; // already a member — idempotent, don't consume the code
    }

    // Consume this specific code and add the member together — only
    // THIS code becomes unusable; any other still-valid codes for the
    // same business are unaffected (per the "multiple concurrent codes"
    // requirement).
    await prisma.$transaction([
      prisma.businessMember.create({
        data: { businessId: business.id, userId, role: 'member' },
      }),
      prisma.inviteCode.update({
        where: { id: invite.id },
        data: { usedAt: new Date(), usedBy: userId },
      }),
    ]);

    return business;
  },

  async listForUser(userId: string) {
    const memberships = await prisma.businessMember.findMany({
      where: { userId },
      include: { business: true },
    });
    return memberships.map((m) => m.business);
  },

  async getById(businessId: string) {
    return prisma.business.findUnique({ where: { id: businessId } });
  },

  async delete(businessId: string) {
    await prisma.business.delete({ where: { id: businessId } });
  },

  async listMembers(businessId: string) {
    const members = await prisma.businessMember.findMany({
      where: { businessId },
      include: { user: true },
      orderBy: { joinedAt: 'asc' },
    });
    return members.map((m) => ({
      userId: m.userId,
      businessId: m.businessId,
      role: m.role,
      joinedAt: m.joinedAt,
      fullName: m.user.fullName,
    }));
  },

  async removeMember(businessId: string, userId: string) {
    await prisma.businessMember.delete({
      where: { businessId_userId: { businessId, userId } },
    });
  },
};
