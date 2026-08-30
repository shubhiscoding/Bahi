import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { requireMembership, requireOwner } from '../middleware/businessAccess';
import { businessService } from '../services/businessService';
import { emitToBusiness } from '../sockets';
import { asyncHandler } from '../utils/asyncHandler';

export const businessRoutes = Router();

businessRoutes.use(requireAuth);

businessRoutes.post(
  '/',
  asyncHandler(async (req, res) => {
    const { name } = req.body;
    if (!name?.trim()) return res.status(400).json({ error: 'name is required' });

    const business = await businessService.create(req.user!.id, name.trim());
    res.status(201).json(business);
  }),
);

businessRoutes.post(
  '/join',
  asyncHandler(async (req, res) => {
    const { inviteCode } = req.body;
    if (!inviteCode?.trim()) return res.status(400).json({ error: 'inviteCode is required' });

    try {
      const business = await businessService.joinByCode(req.user!.id, inviteCode.trim());
      emitToBusiness(business.id, 'member:added', { userId: req.user!.id, fullName: req.user!.fullName });
      res.json(business);
    } catch (err: any) {
      if (err.message === 'CODE_NOT_FOUND') {
        return res.status(404).json({ error: 'CODE_NOT_FOUND' });
      }
      throw err;
    }
  }),
);

businessRoutes.get(
  '/mine',
  asyncHandler(async (req, res) => {
    const businesses = await businessService.listForUser(req.user!.id);
    res.json(businesses);
  }),
);

businessRoutes.get(
  '/:businessId',
  requireMembership,
  asyncHandler(async (req, res) => {
    const business = await businessService.getById(req.params.businessId);
    res.json(business);
  }),
);

businessRoutes.delete(
  '/:businessId',
  requireOwner,
  asyncHandler(async (req, res) => {
    await businessService.delete(req.params.businessId);
    res.status(204).send();
  }),
);

// Owner-only: generates a fresh 5-minute, single-use invite code —
// called right when the owner taps "Share" in the app, not stored/shown
// permanently anywhere.
businessRoutes.post(
  '/:businessId/invite-code',
  requireOwner,
  asyncHandler(async (req, res) => {
    const result = await businessService.generateInviteCode(req.params.businessId, req.user!.id);
    res.json(result);
  }),
);

businessRoutes.get(
  '/:businessId/members',
  requireMembership,
  asyncHandler(async (req, res) => {
    const members = await businessService.listMembers(req.params.businessId);
    res.json(members);
  }),
);

businessRoutes.delete(
  '/:businessId/members/:userId',
  requireOwner,
  asyncHandler(async (req, res) => {
    const { businessId, userId } = req.params;
    await businessService.removeMember(businessId, userId);
    emitToBusiness(businessId, 'member:removed', { userId });
    res.status(204).send();
  }),
);
