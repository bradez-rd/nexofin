import { Router } from 'express';
import { CategoryController } from '../controllers/CategoryController.js';
import { PostgresCategoryRepository } from '../../infrastructure/repositories/PostgresCategoryRepository.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';

const router = Router();
const categoryRepository = new PostgresCategoryRepository();
const categoryController = new CategoryController(categoryRepository);

router.use(authMiddleware);

router.get('/', categoryController.list);
router.post('/', categoryController.create);

export default router;
