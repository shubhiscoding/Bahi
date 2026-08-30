import { prisma } from '../prisma';
import { generateInviteCode } from '../utils/inviteCode';

const INVITE_CODE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export const businessService = {
  async create(ownerId: string, name: string) {
    // No invite code generated here anymore — codes are ephemeral,
    // generated on demand when the owner taps "Share" (generateInviteCode
    // below), not a permanent business attribute.
    return prisma.business.create({
      data: {
        name,
        ownerId,
        members: {
          create: { userId: ownerId, role: 'owner' },
        },
      },
    });
  },

  /**
   * Generates a fresh OTP-style invite code: valid 5 minutes, single-use.
   * Overwrites any previous code for this business (old one becomes
   * unreachable immediately — there's only ever one "current" code).
   */
  async generateInviteCode(businessId: string) {
    const code = generateInviteCode();
    const expiresAt = new Date(Date.now() + INVITE_CODE_TTL_MS);

    await prisma.business.update({
      where: { id: businessId },
      data: {
        inviteCode: code,
        inviteCodeExpiresAt: expiresAt,
        inviteCodeUsedAt: null,
      },
    });

    return { code, expiresAt };
  },

  async joinByCode(userId: string, inviteCode: string) {
    const business = await prisma.business.findFirst({
      where: {
        inviteCode: inviteCode.toUpperCase(),
        inviteCodeExpiresAt: { gt: new Date() },
        inviteCodeUsedAt: null,
      },
    });

    // Deliberately one generic message for "not found" / "expired" /
    // "already used" — design.md rule 11: one plain sentence, don't make
    // the user parse different failure reasons.
    if (!business) {
      throw new Error('CODE_NOT_FOUND');
    }

    const existing = await prisma.businessMember.findUnique({
      where: { businessId_userId: { businessId: business.id, userId } },
    });
    if (existing) {
      return business; // already a member — idempotent, don't consume the code
    }

    // Consume the code and add the member together — code becomes
    // unusable the instant it succeeds once, per the single-use rule.
    await prisma.$transaction([
      prisma.businessMember.create({
        data: { businessId: business.id, userId, role: 'member' },
      }),
      prisma.business.update({
        where: { id: business.id },
        data: { inviteCodeUsedAt: new Date() },
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
