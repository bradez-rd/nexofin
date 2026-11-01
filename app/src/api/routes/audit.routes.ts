import { Router } from 'express';
import { AuditService } from '../../application/audit/AuditService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { handler, ok } from '../http.js';

const router = Router();
router.use(authMiddleware);

// Solo lectura: la bitácora no se puede modificar ni eliminar (RF-AUD-01/02)
router.get(
  '/activity',
  handler(async (req, res) => {
    const limit = parseInt(String(req.query.limit ?? '20'), 10) || 20;
    const activity = await AuditService.recentActivity(req.user!.id, limit);
    ok(res, { total: activity.length, activity });
  })
);

export default router;
