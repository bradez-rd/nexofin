import { Router } from 'express';
import { RecurringService } from '../../application/recurring/RecurringService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import { CreateRecurringSchema, UpdateRecurringSchema } from '../dtos/index.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { env } from '../../config/env.js';

const router = Router();
const recurring = new RecurringService();
const today = () => DateRules.todayIn(env.TIMEZONE);

router.use(authMiddleware);

router.post(
  '/',
  validate(CreateRecurringSchema),
  handler(async (req, res) => {
    const created = await recurring.create(req.user!.id, req.body);
    const generadas = await recurring.generateDue(req.user!.id, today());
    ok(res, { recurrente: created, generadas }, 'Recurrencia creada', 201);
  })
);
router.get(
  '/',
  handler(async (req, res) => {
    const generadas = await recurring.generateDue(req.user!.id, today());
    const list = await recurring.list(req.user!.id);
    ok(res, { total: list.length, generadas, recurrentes: list });
  })
);
router.post('/generate', handler(async (req, res) => ok(res, { generadas: await recurring.generateDue(req.user!.id, today()) })));
router.put(
  '/:id',
  validate(UpdateRecurringSchema),
  handler(async (req, res) =>
    ok(res, { recurrente: await recurring.update(req.user!.id, req.params.id as string, req.body) }, 'Recurrencia actualizada')
  )
);
router.delete(
  '/:id',
  handler(async (req, res) =>
    ok(res, { recurrente: await recurring.finish(req.user!.id, req.params.id as string) }, 'Recurrencia finalizada')
  )
);

export default router;
