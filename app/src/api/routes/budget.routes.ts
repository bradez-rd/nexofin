import { Router } from 'express';
import { BudgetService } from '../../application/budgets/BudgetService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import { CreateBudgetSchema, UpdateBudgetSchema } from '../dtos/index.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { env } from '../../config/env.js';

const router = Router();
const budgets = new BudgetService();

router.use(authMiddleware);

router.get(
  '/',
  handler(async (req, res) => {
    const mes = (req.query.mes as string | undefined) ?? DateRules.todayIn(env.TIMEZONE).slice(0, 7);
    const list = await budgets.list(req.user!.id, mes);
    ok(res, { mes, total: list.length, budgets: list });
  })
);
router.post(
  '/',
  validate(CreateBudgetSchema),
  handler(async (req, res) => ok(res, { budget: await budgets.create(req.user!.id, req.body) }, 'Presupuesto creado', 201))
);
router.put(
  '/:id',
  validate(UpdateBudgetSchema),
  handler(async (req, res) =>
    ok(res, { budget: await budgets.update(req.user!.id, req.params.id as string, req.body) }, 'Presupuesto actualizado')
  )
);
router.delete(
  '/:id',
  handler(async (req, res) => {
    await budgets.remove(req.user!.id, req.params.id as string);
    ok(res, {}, 'Presupuesto eliminado');
  })
);

export default router;
