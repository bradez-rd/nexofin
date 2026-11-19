import { Router } from 'express';
import { SimulationService } from '../../application/simulation/SimulationService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import {
  SimulateExpenseSchema,
  SimulateSavingSchema,
  SimulateInstallmentsSchema,
  CompareSimulationsSchema,
} from '../dtos/index.js';

const router = Router();
const simulations = new SimulationService();

router.use(authMiddleware);

const run = (tipo: 'gasto' | 'ahorro_meta' | 'compra_cuotas') =>
  handler(async (req, res) => {
    const { guardar, ...params } = req.body;
    ok(res, { simulacion: await simulations.simulate(req.user!.id, tipo, params, guardar) }, 'Simulación calculada', 201);
  });

router.post('/expense', validate(SimulateExpenseSchema), run('gasto'));
router.post('/saving', validate(SimulateSavingSchema), run('ahorro_meta'));
router.post('/installments', validate(SimulateInstallmentsSchema), run('compra_cuotas'));

router.post(
  '/compare',
  validate(CompareSimulationsSchema),
  handler(async (req, res) => ok(res, await simulations.compare(req.user!.id, req.body.ids)))
);
router.get(
  '/',
  handler(async (req, res) => {
    const list = await simulations.list(req.user!.id, req.query.todas !== 'true');
    ok(res, { total: list.length, simulaciones: list });
  })
);
router.get('/:id', handler(async (req, res) => ok(res, { simulacion: await simulations.get(req.user!.id, req.params.id as string) })));
router.post(
  '/:id/save',
  handler(async (req, res) => ok(res, { simulacion: await simulations.save(req.user!.id, req.params.id as string) }, 'Simulación guardada'))
);
router.post(
  '/:id/recalculate',
  handler(async (req, res) => ok(res, await simulations.recalculate(req.user!.id, req.params.id as string), 'Simulación recalculada con tus datos actuales'))
);
router.delete(
  '/:id',
  handler(async (req, res) => {
    await simulations.remove(req.user!.id, req.params.id as string);
    ok(res, {}, 'Simulación eliminada del historial');
  })
);

export default router;
