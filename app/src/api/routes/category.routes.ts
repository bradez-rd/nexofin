import { Router } from 'express';
import { CategoryController } from '../controllers/CategoryController.js';
import { PostgresCategoryRepository } from '../../infrastructure/repositories/PostgresCategoryRepository.js';
import { CategorizationService } from '../../application/categories/CategorizationService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import {
  CreateRuleSchema,
  UpdateRuleSchema,
  CategorizeSchema,
  UpdateCategorySchema,
} from '../dtos/index.js';

const router = Router();
const categoryRepository = new PostgresCategoryRepository();
const categoryController = new CategoryController(categoryRepository);
const categorization = new CategorizationService();

router.use(authMiddleware);

router.get('/', categoryController.list);
router.post('/', categoryController.create);

// Reglas de categorización (RF-CAT-02)
router.get('/rules', handler(async (req, res) => ok(res, { rules: await categorization.listRules(req.user!.id) })));
router.post(
  '/rules',
  validate(CreateRuleSchema),
  handler(async (req, res) => ok(res, { rule: await categorization.createRule(req.user!.id, req.body) }, 'Regla creada', 201))
);
router.put(
  '/rules/:id',
  validate(UpdateRuleSchema),
  handler(async (req, res) =>
    ok(res, { rule: await categorization.updateRule(req.user!.id, req.params.id as string, req.body) }, 'Regla actualizada')
  )
);
router.delete(
  '/rules/:id',
  handler(async (req, res) => {
    await categorization.deleteRule(req.user!.id, req.params.id as string);
    ok(res, {}, 'Regla eliminada');
  })
);

// Bandeja de revisión y reproceso (RF-CAT-03/06)
router.get(
  '/review',
  handler(async (req, res) => {
    const items = await categorization.reviewInbox(req.user!.id);
    ok(res, { total: items.length, items });
  })
);
router.post('/reprocess', handler(async (req, res) => ok(res, { actualizadas: await categorization.reprocess(req.user!.id) })));
router.post(
  '/transactions/:id',
  validate(CategorizeSchema),
  handler(async (req, res) =>
    ok(
      res,
      await categorization.categorize(req.user!.id, req.params.id as string, req.body.categoria_id, req.body.crear_regla),
      'Categoría corregida'
    )
  )
);

// Categorías personalizadas (RF-CAT-04/05)
router.put(
  '/:id',
  validate(UpdateCategorySchema),
  handler(async (req, res) =>
    ok(res, { category: await categorization.updateCategory(req.user!.id, req.params.id as string, req.body) }, 'Categoría actualizada')
  )
);
router.delete(
  '/:id',
  handler(async (req, res) => {
    await categorization.deleteCategory(req.user!.id, req.params.id as string, req.query.reasignar_a as string | undefined);
    ok(res, {}, 'Categoría eliminada');
  })
);

export default router;
