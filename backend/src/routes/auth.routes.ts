import { Router } from 'express';
import { requireAuth, upsertProfileFromAuth } from '../middleware/auth';

export const authRoutes = Router();

// Called by the Flutter app right after every successful sign-in.
authRoutes.post('/sync', requireAuth, async (req, res) => {
  const profile = await upsertProfileFromAuth(req.user!);
  res.json(profile);
});

authRoutes.get('/me', requireAuth, async (req, res) => {
  res.json(req.user);
});
