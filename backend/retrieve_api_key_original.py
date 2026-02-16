"""
Simple override for local development.
Checks BACKEND_API_KEY environment variable first,
falls back to AWS credential provider if not set.
"""
import os
import logging

def retrieve_api_key(credential_provider_name: str) -> str:
    """
    Retrieve API key from environment variable or AWS credential provider.
    
    For local development, set BACKEND_API_KEY environment variable.
    For production, uses AWS Bedrock Credential Provider.
    """
    # Check environment variable first (dev mode)
    env_api_key = os.getenv('BACKEND_API_KEY')
    if env_api_key:
        logging.info("Using API key from BACKEND_API_KEY environment variable (dev mode)")
        return env_api_key
    
    # Fall back to original implementation
    logging.info(f"Attempting to retrieve API key from credential provider: {credential_provider_name}")
    
    # Import the original function
    from retrieve_api_key_original import retrieve_api_key as original_retrieve
    return original_retrieve(credential_provider_name)
