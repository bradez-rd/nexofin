import { Router } from 'express';
import { DashboardService } from '../../application/dashboard/DashboardService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { handler, ok } from '../http.js';
import { ValidationError } from '../../domain/errors/DomainError.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { env } from '../../config/env.js';

const router = Router();
const dashboard = new DashboardService();

router.use(authMiddleware);

const q = (v: unknown): string | undefined => (typeof v === 'string' && v.length > 0 ? v : undefined);

router.get(
  '/summary',
  handler(async (req, res) => {
    const hoy = DateRules.todayIn(env.TIMEZONE);
    const desde = q(req.query.desde) ?? DateUtils.monthStart(hoy);
    const hasta = q(req.query.hasta) ?? hoy;
    ok(res, await dashboard.summary(req.user!.id, desde, hasta));
  })
);
router.get('/position', handler(async (req, res) => ok(res, await dashboard.position(req.user!.id))));
router.get(
  '/spending',
  handler(async (req, res) => {
    const mes = q(req.query.mes) ?? DateRules.todayIn(env.TIMEZONE).slice(0, 7);
    ok(res, await dashboard.spendingDistribution(req.user!.id, mes));
  })
);
router.get(
  '/trend',
  handler(async (req, res) => ok(res, await dashboard.trend(req.user!.id, parseInt(String(req.query.meses ?? '6'), 10) || 6)))
);
router.get(
  '/export',
  handler(async (req, res) => {
    const formato = (q(req.query.formato) ?? 'csv') as 'csv' | 'xlsx' | 'pdf';
    if (!['csv', 'xlsx', 'pdf'].includes(formato)) throw new ValidationError('El formato debe ser csv, xlsx o pdf');
    const file = await dashboard.export(req.user!.id, formato, {
      desde: q(req.query.desde),
      hasta: q(req.query.hasta),
      cuenta_id: q(req.query.cuenta_id),
      categoria_id: q(req.query.categoria_id),
      tipo: q(req.query.tipo),
      busqueda: q(req.query.busqueda),
    });
    res.setHeader('Content-Type', file.contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${file.filename}"`);
    res.status(200).send(file.buffer);
  })
);

export default router;
