import os
import logging

def retrieve_api_key(credential_provider_name: str) -> str:
    """
    Retrieve API key from BACKEND_API_KEY environment variable.
    For local dev: uses env var
    For production: would use AWS Bedrock Credential Provider
    """
    api_key = os.getenv('BACKEND_API_KEY')
    
    if not api_key:
        raise RuntimeError(
            "BACKEND_API_KEY environment variable not set.\n"
            "Set it with: export BACKEND_API_KEY='your-key-here'"
        )
    
    logging.info("✅ Using API key from BACKEND_API_KEY environment variable")
    return api_key
