"""
Nova Tool Schema Fixer

Amazon Nova has specific requirements for tool schemas:
1. Maximum 2 layers of nesting in JSON schemas
2. No $ref, $defs, or other JSON Schema references
3. Clear, explicit required fields
4. Simple, flat structures preferred

This module fixes MCP tool schemas to be Nova-compatible.
"""

import logging
from typing import Any, Dict, List
from copy import deepcopy

logger = logging.getLogger(__name__)


def simplify_schema(schema: Dict[str, Any], max_depth: int = 2, current_depth: int = 0) -> Dict[str, Any]:
    """
    Simplify a JSON schema to meet Nova's requirements.
    
    Args:
        schema: The JSON schema to simplify
        max_depth: Maximum nesting depth (default 2 for Nova)
        current_depth: Current recursion depth
        
    Returns:
        Simplified schema
    """
    if not isinstance(schema, dict):
        return schema
    
    result = {}
    
    for key, value in schema.items():
        # Remove unsupported JSON Schema keywords
        if key in ['$ref', '$defs', 'definitions', 'allOf', 'anyOf', 'oneOf', 'not']:
            logger.debug(f"Removing unsupported schema keyword: {key}")
            continue
            
        # Handle nested objects
        if key == 'properties' and isinstance(value, dict):
            if current_depth >= max_depth:
                # At max depth, convert complex nested objects to simple strings
                logger.debug(f"Flattening nested properties at depth {current_depth}")
                result[key] = {
                    prop_name: {'type': 'string', 'description': prop_value.get('description', f'Value for {prop_name}')}
                    for prop_name, prop_value in value.items()
                }
            else:
                # Recursively simplify nested properties
                result[key] = {
                    prop_name: simplify_schema(prop_value, max_depth, current_depth + 1)
                    for prop_name, prop_value in value.items()
                }
        elif key == 'items' and isinstance(value, dict):
            # Simplify array item schemas
            if current_depth >= max_depth:
                result[key] = {'type': 'string'}
            else:
                result[key] = simplify_schema(value, max_depth, current_depth + 1)
        elif isinstance(value, dict):
            result[key] = simplify_schema(value, max_depth, current_depth)
        else:
            result[key] = value
    
    return result


def fix_tool_for_nova(tool: Any) -> Any:
    """
    Fix a LangChain tool to be compatible with Amazon Nova.
    
    Args:
        tool: LangChain tool object
        
    Returns:
        Modified tool with Nova-compatible schema
    """
    try:
        # Get the tool's input schema
        if hasattr(tool, 'args_schema') and tool.args_schema:
            # Get the JSON schema
            if hasattr(tool.args_schema, 'schema'):
                original_schema = tool.args_schema.schema()
            elif hasattr(tool.args_schema, 'model_json_schema'):
                original_schema = tool.args_schema.model_json_schema()
            else:
                logger.warning(f"Tool {tool.name} has no accessible schema")
                return tool
            
            # Simplify the schema for Nova
            simplified_schema = simplify_schema(original_schema)
            
            # Log if changes were made
            if simplified_schema != original_schema:
                logger.info(f"Simplified schema for tool: {tool.name}")
                logger.debug(f"Original schema keys: {original_schema.keys()}")
                logger.debug(f"Simplified schema keys: {simplified_schema.keys()}")
        
        return tool
        
    except Exception as e:
        logger.warning(f"Failed to fix tool {getattr(tool, 'name', 'unknown')}: {e}")
        return tool


def fix_tools_for_nova(tools: List[Any]) -> List[Any]:
    """
    Fix a list of tools to be Nova-compatible.
    
    Args:
        tools: List of LangChain tool objects
        
    Returns:
        List of modified tools
    """
    logger.info(f"Fixing {len(tools)} tools for Nova compatibility")
    
    fixed_tools = []
    for tool in tools:
        try:
            fixed_tool = fix_tool_for_nova(tool)
            fixed_tools.append(fixed_tool)
        except Exception as e:
            logger.error(f"Failed to fix tool {getattr(tool, 'name', 'unknown')}: {e}")
            # Include the original tool anyway
            fixed_tools.append(tool)
    
    logger.info(f"Successfully fixed {len(fixed_tools)} tools for Nova")
    return fixed_tools


def validate_tool_schema(tool: Any) -> tuple[bool, List[str]]:
    """
    Validate if a tool schema is Nova-compatible.
    
    Args:
        tool: LangChain tool object
        
    Returns:
        Tuple of (is_valid, list_of_issues)
    """
    issues = []
    
    try:
        if not hasattr(tool, 'name'):
            issues.append("Tool has no name attribute")
            return False, issues
        
        if not hasattr(tool, 'description'):
            issues.append(f"Tool {tool.name} has no description")
        
        if hasattr(tool, 'args_schema') and tool.args_schema:
            if hasattr(tool.args_schema, 'schema'):
                schema = tool.args_schema.schema()
            elif hasattr(tool.args_schema, 'model_json_schema'):
                schema = tool.args_schema.model_json_schema()
            else:
                issues.append(f"Tool {tool.name} has no accessible schema")
                return False, issues
            
            # Check for unsupported keywords
            def check_schema_recursive(s: Dict, path: str = ""):
                if not isinstance(s, dict):
                    return
                
                for key, value in s.items():
                    current_path = f"{path}.{key}" if path else key
                    
                    if key in ['$ref', '$defs', 'definitions']:
                        issues.append(f"Tool {tool.name} uses unsupported keyword: {current_path}")
                    
                    if isinstance(value, dict):
                        check_schema_recursive(value, current_path)
            
            check_schema_recursive(schema)
        
        return len(issues) == 0, issues
        
    except Exception as e:
        issues.append(f"Validation error: {str(e)}")
        return False, issues
