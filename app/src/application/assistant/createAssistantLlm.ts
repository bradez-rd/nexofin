import { env } from '../../config/env.js';
import { createLlmClient } from '../../infrastructure/ai/LlmClient.js';
import { AssistantLlm } from './AssistantLlm.js';
import { ClaudeProvider } from './ClaudeAssistant.js';
import { GeminiHttpClient, GeminiProvider } from './GeminiProvider.js';

/**
 * Elige el proveedor de IA según la configuración: LLM_PROVIDER=claude|gemini|reglas, o "auto" (por defecto):
 * Gemini si hay GEMINI_API_KEY (tiene capa gratuita), si no Claude si hay ANTHROPIC_API_KEY, si no ninguno
 * y el asistente responde con su motor de reglas local.
 */
export function createAssistantLlm(): AssistantLlm | null {
  const choice = env.LLM_PROVIDER;
  if (choice === 'reglas') return null;
  if ((choice === 'gemini' || choice === 'auto') && env.GEMINI_API_KEY) {
    return new GeminiProvider(new GeminiHttpClient(env.GEMINI_API_KEY));
  }
  if (choice === 'gemini') return null;
  const claude = createLlmClient();
  return claude ? new ClaudeProvider(claude) : null;
}
