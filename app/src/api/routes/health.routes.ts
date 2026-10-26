import { Router } from 'express';
import { HealthController } from '../controllers/HealthController.js';

const router = Router();
const healthController = new HealthController();

router.get('/', healthController.check);

export default router;
