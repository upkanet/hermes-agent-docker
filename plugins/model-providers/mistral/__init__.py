"""Mistral AI provider profile.

Mistral provides an OpenAI-compatible chat completions API.
Models: mistral-large-2411, mistral-small-2503, mistral-moderation-latest, etc.
"""

from providers import register_provider
from providers.base import ProviderProfile


mistral = ProviderProfile(
    name="mistral",
    aliases=("mistral-ai", "le-chat", "mistral-large", "mistral-small"),
    env_vars=("MISTRAL_API_KEY",),
    display_name="Mistral AI",
    description="Mistral AI — OpenAI-compatible chat completions",
    signup_url="https://console.mistral.ai/",
    base_url="https://api.mistral.ai/v1",
    models_url="https://api.mistral.ai/v1/models",
    fallback_models=(
        "mistral-large-2411",
        "mistral-small-2503",
    ),
)

register_provider(mistral)
