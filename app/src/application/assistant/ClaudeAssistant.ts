import type Anthropic from '@anthropic-ai/sdk';
import { LlmClient } from '../../infrastructure/ai/LlmClient.js';
import { env } from '../../config/env.js';
import {
  AssistantLlm,
  ASSISTANT_SYSTEM_PROMPT,
  HistoryMessage,
  LOOP_EXHAUSTED_TEXT,
  MAX_TOOL_ITERATIONS,
  REFUSAL_TEXT,
  TOOL_SPECS,
  ToolExecutor,
  TurnResult,
} from './AssistantLlm.js';

const CLAUDE_TOOLS: Anthropic.Tool[] = TOOL_SPECS.map((t) => ({
  name: t.name,
  description: t.description,
  input_schema: t.parameters as Anthropic.Tool.InputSchema,
}));

/** Proveedor Claude (Anthropic): bucle de herramientas sobre la API de mensajes. */
export class ClaudeProvider implements AssistantLlm {
  public readonly name = 'claude' as const;

  constructor(private readonly client: LlmClient) {}

  public async runTurn(history: HistoryMessage[], userMessage: string, execute: ToolExecutor): Promise<TurnResult> {
    const messages: Anthropic.MessageParam[] = [...history.map((h) => ({ role: h.role, content: h.content })), { role: 'user', content: userMessage }];
    const toolsUsed: string[] = [];

    for (let i = 0; i < MAX_TOOL_ITERATIONS; i++) {
      const response = await this.client.messages.create({
        model: env.ANTHROPIC_MODEL,
        max_tokens: 2048,
        system: ASSISTANT_SYSTEM_PROMPT,
        tools: CLAUDE_TOOLS,
        output_config: { effort: 'medium' },
        messages,
      });

      if (response.stop_reason === 'refusal') return { text: REFUSAL_TEXT, toolsUsed, refused: true };
      // Se devuelve el contenido tal cual (incluye bloques de razonamiento) para que el bucle sea válido.
      messages.push({ role: 'assistant', content: response.content });

      if (response.stop_reason !== 'tool_use') {
        const text = response.content
          .filter((b): b is Anthropic.TextBlock => b.type === 'text')
          .map((b) => b.text)
          .join('\n')
          .trim();
        return { text, toolsUsed, refused: false };
      }

      const results: Anthropic.ToolResultBlockParam[] = [];
      for (const block of response.content) {
        if (block.type !== 'tool_use') continue;
        toolsUsed.push(block.name);
        try {
          const r = await execute(block.name, (block.input ?? {}) as Record<string, unknown>);
          results.push({ type: 'tool_result', tool_use_id: block.id, content: r.content, ...(r.isError ? { is_error: true } : {}) });
        } catch (e: any) {
          results.push({ type: 'tool_result', tool_use_id: block.id, content: `No se pudo ejecutar la herramienta: ${e?.message ?? 'error'}`, is_error: true });
        }
      }
      // Todos los resultados de las llamadas en paralelo van en un solo mensaje
      messages.push({ role: 'user', content: results });
    }
    return { text: LOOP_EXHAUSTED_TEXT, toolsUsed, refused: false };
  }
}
