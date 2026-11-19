import { Router } from 'express';
import { DebtService } from '../../application/debts/DebtService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import { CreateDebtSchema, PayDebtSchema } from '../dtos/index.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { env } from '../../config/env.js';

const router = Router();
const debts = new DebtService();

router.use(authMiddleware);

router.post(
  '/',
  validate(CreateDebtSchema),
  handler(async (req, res) =>
    ok(res, await debts.create(req.user!.id, req.body), 'Deuda registrada con su calendario de cuotas', 201)
  )
);
router.get(
  '/',
  handler(async (req, res) => {
    const list = await debts.list(req.user!.id);
    ok(res, { total: list.length, debts: list });
  })
);
router.get(
  '/calendar',
  handler(async (req, res) => {
    const days = Math.min(Math.max(parseInt(String(req.query.dias ?? '60'), 10) || 60, 1), 365);
    ok(res, { dias: days, items: await debts.calendar(req.user!.id, DateRules.todayIn(env.TIMEZONE), days) });
  })
);
router.get('/:id', handler(async (req, res) => ok(res, await debts.get(req.user!.id, req.params.id as string))));
router.post(
  '/:id/payments',
  validate(PayDebtSchema),
  handler(async (req, res) => ok(res, await debts.pay(req.user!.id, req.params.id as string, req.body), 'Pago registrado', 201))
);

export default router;
