#!/usr/bin/env python3
"""
Deep inspection of MCP tool structure to understand how they're being converted.
"""

import asyncio
import json
import logging
import sys
from pathlib import Path

# Add sre_agent to path
sys.path.insert(0, str(Path(__file__).parent / "sre_agent"))

from sre_agent.multi_agent_langgraph import create_mcp_client

logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def inspect_tools():
    """Deep inspection of MCP tool structure."""
    
    print("=" * 80)
    print("MCP TOOL STRUCTURE INSPECTION")
    print("=" * 80)
    
    # Load tools
    print("\n📥 Loading MCP tools...")
    try:
        client = create_mcp_client()
        tools = await asyncio.wait_for(client.get_tools(), timeout=30)
        print(f"✅ Loaded {len(tools)} tools\n")
    except Exception as e:
        print(f"❌ Failed: {e}")
        return
    
    # Inspect first tool in detail
    if tools:
        tool = tools[0]
        tool_name = getattr(tool, 'name', 'unknown')
        
        print(f"🔍 Inspecting tool: {tool_name}")
        print(f"{'=' * 80}\n")
        
        print("📋 Tool Attributes:")
        for attr in dir(tool):
            if not attr.startswith('_'):
                try:
                    value = getattr(tool, attr)
                    if not callable(value):
                        print(f"  • {attr}: {type(value).__name__}")
                        if attr in ['name', 'description']:
                            print(f"      Value: {value}")
                except:
                    pass
        
        print(f"\n📦 Tool Type: {type(tool)}")
        print(f"📦 Tool Class: {tool.__class__.__name__}")
        print(f"📦 Tool Module: {tool.__class__.__module__}")
        
        # Check for schema-related attributes
        print(f"\n🔍 Schema-related attributes:")
        schema_attrs = ['args_schema', 'args', 'input_schema', 'inputSchema', 'schema', 'parameters']
        for attr in schema_attrs:
            if hasattr(tool, attr):
                value = getattr(tool, attr)
                print(f"  ✅ {attr}: {type(value)}")
                if value is not None:
                    print(f"      {value}")
            else:
                print(f"  ❌ {attr}: Not found")
        
        # Try to get the underlying MCP tool
        print(f"\n🔍 Looking for underlying MCP tool data...")
        if hasattr(tool, '_tool'):
            print(f"  ✅ Found _tool attribute")
            mcp_tool = tool._tool
            print(f"      Type: {type(mcp_tool)}")
            if hasattr(mcp_tool, 'inputSchema'):
                print(f"      inputSchema: {json.dumps(mcp_tool.inputSchema, indent=2)}")
        
        # Check if it's a StructuredTool
        if hasattr(tool, 'func'):
            print(f"\n  ✅ Tool has 'func' attribute (StructuredTool)")
            print(f"      func: {tool.func}")
        
        # Try to invoke the tool to see what happens
        print(f"\n🧪 Testing tool invocation...")
        try:
            # Get the tool's expected input
            if hasattr(tool, 'args_schema') and tool.args_schema:
                print(f"  Tool expects args_schema: {tool.args_schema}")
        except Exception as e:
            print(f"  ⚠️  Could not determine input schema: {e}")
    
    # Show all tool names
    print(f"\n📋 All {len(tools)} tools:")
    for i, tool in enumerate(tools, 1):
        tool_name = getattr(tool, 'name', 'unknown')
        tool_desc = getattr(tool, 'description', 'No description')
        print(f"  {i}. {tool_name}")
        print(f"     {tool_desc[:80]}...")
    
    print("\n" + "=" * 80)


if __name__ == "__main__":
    asyncio.run(inspect_tools())
