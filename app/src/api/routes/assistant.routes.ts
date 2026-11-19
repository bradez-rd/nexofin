import { Router } from 'express';
import { AssistantService } from '../../application/assistant/AssistantService.js';
import { SimulationService } from '../../application/simulation/SimulationService.js';
import { BudgetService } from '../../application/budgets/BudgetService.js';
import { GoalService } from '../../application/goals/GoalService.js';
import { DebtService } from '../../application/debts/DebtService.js';
import { TransactionService } from '../../application/transactions/TransactionService.js';
import { PostgresTransactionRepository } from '../../infrastructure/repositories/PostgresTransactionRepository.js';
import { PostgresAccountRepository } from '../../infrastructure/repositories/PostgresAccountRepository.js';
import { PostgresCategoryRepository } from '../../infrastructure/repositories/PostgresCategoryRepository.js';
import { createAssistantLlm } from '../../application/assistant/createAssistantLlm.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import { AssistantMessageSchema } from '../dtos/index.js';

const router = Router();
const assistant = new AssistantService(
  new SimulationService(),
  new BudgetService(),
  new GoalService(),
  new DebtService(),
  new TransactionService(
    new PostgresTransactionRepository(),
    new PostgresAccountRepository(),
    new PostgresCategoryRepository()
  ),
  // Gemini o Claude interpretan la pregunta si hay clave configurada; si no, responde el motor de reglas
  createAssistantLlm()
);

router.use(authMiddleware);

router.post(
  '/messages',
  validate(AssistantMessageSchema),
  handler(async (req, res) => ok(res, await assistant.send(req.user!.id, req.body.mensaje, req.body.conversacion_id), undefined, 201))
);
router.get(
  '/conversations',
  handler(async (req, res) => ok(res, { conversaciones: await assistant.listConversations(req.user!.id) }))
);
router.get(
  '/conversations/:id/messages',
  handler(async (req, res) => ok(res, { mensajes: await assistant.messages(req.user!.id, req.params.id as string) }))
);
router.delete(
  '/conversations/:id',
  handler(async (req, res) => {
    await assistant.deleteConversation(req.user!.id, req.params.id as string);
    ok(res, {}, 'Conversación eliminada');
  })
);

export default router;
