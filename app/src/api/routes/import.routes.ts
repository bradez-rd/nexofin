import express, { Router } from 'express';
import { ImportService, MappingRequiredError } from '../../application/imports/ImportService.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { handler, ok } from '../http.js';
import { UploadImportSchema, UpdateImportMovementSchema } from '../dtos/index.js';

const router = Router();
const imports = new ImportService();

// Los archivos viajan en base64 dentro del JSON: se amplía el límite solo para este módulo
router.use(express.json({ limit: '9mb' }));
router.use(authMiddleware);

router.post(
  '/',
  validate(UploadImportSchema),
  handler(async (req, res) => {
    try {
      ok(res, await imports.upload(req.user!.id, req.body), 'Archivo procesado. Revisa los movimientos antes de confirmar', 201);
    } catch (e) {
      if (e instanceof MappingRequiredError) {
        res.status(422).json({
          success: false,
          error: { code: 'MappingRequired', message: e.message, necesita_mapeo: true, columnas: e.columnas, muestra: e.muestra },
        });
        return;
      }
      throw e;
    }
  })
);
router.get(
  '/',
  handler(async (req, res) => {
    const list = await imports.list(req.user!.id);
    ok(res, { total: list.length, importaciones: list });
  })
);
router.get('/:id', handler(async (req, res) => ok(res, await imports.get(req.user!.id, req.params.id as string))));
router.put(
  '/:id/movements/:movementId',
  validate(UpdateImportMovementSchema),
  handler(async (req, res) => ok(res, await imports.updateMovement(req.user!.id, req.params.id as string, req.params.movementId as string, req.body)))
);
router.post('/:id/confirm', handler(async (req, res) => ok(res, await imports.confirm(req.user!.id, req.params.id as string), 'Importación confirmada')));
router.post('/:id/cancel', handler(async (req, res) => ok(res, await imports.cancel(req.user!.id, req.params.id as string), 'Importación cancelada')));
router.post('/:id/revert', handler(async (req, res) => ok(res, await imports.revert(req.user!.id, req.params.id as string), 'Importación deshecha')));

export default router;
