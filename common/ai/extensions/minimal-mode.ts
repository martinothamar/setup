import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  createBashTool,
  createEditTool,
  createFindTool,
  createGrepTool,
  createLsTool,
  createReadTool,
  createWriteTool,
} from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

const COLLAPSED_MAX_LINES = 5;

function renderCollapsedResult(result: any, theme: any) {
  const textBlocks = result.content
    .filter((block: any) => block.type === "text" && block.text)
    .map((block: any) => block.text);

  if (textBlocks.length === 0) {
    return new Text("", 0, 0);
  }

  const lines = textBlocks.join("\n").trimEnd().split("\n");
  const preview = lines.slice(0, COLLAPSED_MAX_LINES).map((line) => theme.fg("toolOutput", line)).join("\n");
  const suffix = lines.length > COLLAPSED_MAX_LINES
    ? `\n${theme.fg("muted", `... ${lines.length - COLLAPSED_MAX_LINES} more lines`)}`
    : "";

  return new Text(`\n${preview}${suffix}`, 0, 0);
}

function registerMinimalTool(pi: ExtensionAPI, createTool: (cwd: string) => any) {
  const renderedTool = createTool(process.cwd());

  pi.registerTool({
    ...renderedTool,
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      return createTool(ctx.cwd).execute(toolCallId, params, signal, onUpdate);
    },
    renderResult(result, options, theme, context) {
      if (!options.expanded) {
        return renderCollapsedResult(result, theme);
      }
      return renderedTool.renderResult
        ? renderedTool.renderResult(result, options, theme, context)
        : new Text("", 0, 0);
    },
  });
}

export default function (pi: ExtensionAPI) {
  registerMinimalTool(pi, createReadTool);
  registerMinimalTool(pi, createBashTool);
  registerMinimalTool(pi, createEditTool);
  registerMinimalTool(pi, createWriteTool);
  registerMinimalTool(pi, createFindTool);
  registerMinimalTool(pi, createGrepTool);
  registerMinimalTool(pi, createLsTool);
}
