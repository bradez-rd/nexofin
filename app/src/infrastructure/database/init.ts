import { db } from './db.js';

async function main() {
  console.log('Iniciando inicialización de la base de datos NexoFin...');
  try {
    await db.initSchema();
    console.log('Base de datos inicializada correctamente.');
  } catch (err) {
    console.error('Error durante la inicialización:', err);
    process.exit(1);
  } finally {
    await db.close();
  }
}

main();
