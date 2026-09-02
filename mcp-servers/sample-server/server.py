# version: 0.1.0
# Sample MCP server for testing mcp-manager

import anyio
import mcp_types as types
from mcp.server import Server
from mcp.server.stdio import stdio_server


async def list_tools(ctx, params):
    return types.ListToolsResult(tools=[
        types.Tool(
            name="echo",
            description="Echo back the input message.",
            inputSchema={"type": "object", "properties": {"message": {"type": "string"}}},
        ),
        types.Tool(
            name="greet",
            description="Return a greeting for the given name.",
            inputSchema={"type": "object", "properties": {"name": {"type": "string"}}},
        ),
    ])


async def call_tool(ctx, params):
    if params.name == "echo":
        message = params.arguments.get("message", "")
        return types.CallToolResult(content=[types.TextContent(text=message)])
    elif params.name == "greet":
        name = params.arguments.get("name", "")
        return types.CallToolResult(content=[types.TextContent(text=f"Hello, {name}!")])
    return types.CallToolResult(content=[types.TextContent(text=f"Unknown tool: {params.name}")], isError=True)


app = Server("sample-server", on_list_tools=list_tools, on_call_tool=call_tool)


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


if __name__ == "__main__":
    anyio.run(main)
