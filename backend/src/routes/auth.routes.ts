import { Router } from 'express';
import { requireAuth, upsertProfileFromAuth } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

export const authRoutes = Router();

// Called by the Flutter app right after every successful sign-in.
authRoutes.post(
  '/sync',
  requireAuth,
  asyncHandler(async (req, res) => {
    const profile = await upsertProfileFromAuth(req.user!);
    res.json(profile);
  }),
);

authRoutes.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json(req.user);
  }),
);
