#!/usr/bin/env python3
"""
Test script to validate MCP tools for Nova compatibility and test with a simple query.
"""

import asyncio
import logging
import sys
from pathlib import Path

# Add sre_agent to path
sys.path.insert(0, str(Path(__file__).parent / "sre_agent"))

from sre_agent.multi_agent_langgraph import create_mcp_client
from sre_agent.nova_tool_fixer import validate_tool_schema, fix_tools_for_nova

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def test_mcp_tools():
    """Test MCP tools for Nova compatibility."""
    
    print("=" * 80)
    print("NOVA TOOL COMPATIBILITY TEST")
    print("=" * 80)
    
    # Step 1: Load MCP tools
    print("\n📥 Step 1: Loading MCP tools from gateway...")
    try:
        client = create_mcp_client()
        tools = await asyncio.wait_for(client.get_tools(), timeout=30)
        print(f"✅ Loaded {len(tools)} tools from MCP gateway")
    except Exception as e:
        print(f"❌ Failed to load MCP tools: {e}")
        return False
    
    # Step 2: Validate each tool
    print(f"\n🔍 Step 2: Validating {len(tools)} tools for Nova compatibility...")
    validation_results = []
    
    for tool in tools:
        tool_name = getattr(tool, 'name', 'unknown')
        is_valid, issues = validate_tool_schema(tool)
        validation_results.append((tool_name, is_valid, issues))
        
        if is_valid:
            print(f"  ✅ {tool_name}: Valid")
        else:
            print(f"  ⚠️  {tool_name}: Issues found")
            for issue in issues:
                print(f"      - {issue}")
    
    # Summary
    valid_count = sum(1 for _, is_valid, _ in validation_results if is_valid)
    invalid_count = len(validation_results) - valid_count
    
    print(f"\n📊 Validation Summary:")
    print(f"  ✅ Valid tools: {valid_count}/{len(tools)}")
    print(f"  ⚠️  Tools with issues: {invalid_count}/{len(tools)}")
    
    # Step 3: Fix tools if needed
    if invalid_count > 0:
        print(f"\n🔧 Step 3: Fixing {invalid_count} tools for Nova compatibility...")
        fixed_tools = fix_tools_for_nova(tools)
        print(f"✅ Fixed {len(fixed_tools)} tools")
        
        # Re-validate
        print("\n🔍 Re-validating fixed tools...")
        revalidation_results = []
        for tool in fixed_tools:
            tool_name = getattr(tool, 'name', 'unknown')
            is_valid, issues = validate_tool_schema(tool)
            revalidation_results.append((tool_name, is_valid, issues))
            
            if not is_valid:
                print(f"  ⚠️  {tool_name}: Still has issues")
                for issue in issues:
                    print(f"      - {issue}")
        
        still_invalid = sum(1 for _, is_valid, _ in revalidation_results if not is_valid)
        print(f"\n📊 After fixing: {len(fixed_tools) - still_invalid}/{len(fixed_tools)} tools are valid")
    else:
        print("\n✅ All tools are already Nova-compatible!")
    
    # Step 4: Show tool details
    print(f"\n📋 Step 4: Tool Details:")
    print(f"\nAvailable MCP Tools ({len(tools)}):")
    for tool in tools:
        tool_name = getattr(tool, 'name', 'unknown')
        tool_desc = getattr(tool, 'description', 'No description')
        print(f"  • {tool_name}")
        print(f"    {tool_desc[:100]}...")
    
    print("\n" + "=" * 80)
    print("TEST COMPLETE")
    print("=" * 80)
    
    return True


async def main():
    """Main entry point."""
    try:
        success = await test_mcp_tools()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
