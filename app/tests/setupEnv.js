// Las pruebas no deben llamar a servicios de IA reales aunque haya claves en .env
process.env.LLM_PROVIDER = 'reglas';
