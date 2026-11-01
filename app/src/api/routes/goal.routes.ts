import { Router } from 'express';
import { GoalService } from '../../application/goals/GoalService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import { CreateGoalSchema, UpdateGoalSchema, ContributeGoalSchema } from '../dtos/index.js';

const router = Router();
const goals = new GoalService();

router.use(authMiddleware);

router.get(
  '/',
  handler(async (req, res) => {
    const list = await goals.list(req.user!.id);
    ok(res, { total: list.length, goals: list });
  })
);
router.post(
  '/',
  validate(CreateGoalSchema),
  handler(async (req, res) => ok(res, { goal: await goals.create(req.user!.id, req.body) }, 'Meta creada', 201))
);
router.get('/:id', handler(async (req, res) => ok(res, { goal: await goals.get(req.user!.id, req.params.id as string) })));
router.put(
  '/:id',
  validate(UpdateGoalSchema),
  handler(async (req, res) => ok(res, { goal: await goals.update(req.user!.id, req.params.id as string, req.body) }, 'Meta actualizada'))
);
router.get(
  '/:id/contributions',
  handler(async (req, res) => ok(res, { contributions: await goals.contributions(req.user!.id, req.params.id as string) }))
);
router.post(
  '/:id/contributions',
  validate(ContributeGoalSchema),
  handler(async (req, res) =>
    ok(res, await goals.contribute(req.user!.id, req.params.id as string, req.body), 'Aporte registrado', 201)
  )
);

export default router;
