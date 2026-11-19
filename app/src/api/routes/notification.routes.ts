import { Router } from 'express';
import { NotificationService } from '../../application/notifications/NotificationService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import { NotificationPrefSchema } from '../dtos/index.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { env } from '../../config/env.js';

const router = Router();
router.use(authMiddleware);

router.get(
  '/',
  handler(async (req, res) => {
    await NotificationService.refreshDueAlerts(req.user!.id, DateRules.todayIn(env.TIMEZONE));
    ok(res, await NotificationService.list(req.user!.id, { soloNoLeidas: req.query.no_leidas === 'true' }));
  })
);
router.get(
  '/preferences',
  handler(async (req, res) => ok(res, { preferences: await NotificationService.preferences(req.user!.id) }))
);
router.put(
  '/preferences/:tipo',
  validate(NotificationPrefSchema),
  handler(async (req, res) =>
    ok(res, {
      preferences: await NotificationService.setPreference(
        req.user!.id,
        req.params.tipo as string,
        req.body.canal_app,
        req.body.canal_correo
      ),
    })
  )
);
router.post(
  '/read-all',
  handler(async (req, res) => {
    await NotificationService.markAllRead(req.user!.id);
    ok(res, {}, 'Notificaciones marcadas como leídas');
  })
);
router.post(
  '/:id/read',
  handler(async (req, res) => {
    await NotificationService.markRead(req.user!.id, req.params.id as string);
    ok(res, {}, 'Notificación marcada como leída');
  })
);

export default router;
