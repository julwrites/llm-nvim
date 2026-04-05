#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.error

# Unified LLM Client for Agent Harness

def call_anthropic(prompt, system=None, model="claude-3-5-sonnet-20240620", api_key=None):
    """Calls Anthropic's Messages API."""
    api_key = api_key or os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY not set")

    url = "https://api.anthropic.com/v1/messages"
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }

    messages = [{"role": "user", "content": prompt}]

    data = {
        "model": model,
        "max_tokens": 4096,
        "messages": messages
    }

    if system:
        data["system"] = system

    req = urllib.request.Request(url, json.dumps(data).encode("utf-8"), headers)

    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode("utf-8"))
            return result["content"][0]["text"]
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        raise Exception(f"Anthropic API Error: {e.code} - {err_body}")

def call_openai(prompt, system=None, model="gpt-4o", api_key=None):
    """Calls OpenAI's Chat Completion API."""
    api_key = api_key or os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY not set")

    url = "https://api.openai.com/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    data = {
        "model": model,
        "messages": messages
    }

    req = urllib.request.Request(url, json.dumps(data).encode("utf-8"), headers)

    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode("utf-8"))
            return result["choices"][0]["message"]["content"]
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        raise Exception(f"OpenAI API Error: {e.code} - {err_body}")

def complete(prompt, provider="anthropic", system=None, model=None):
    """Unified completion function."""

    # Provider selection logic
    if provider == "anthropic":
        return call_anthropic(prompt, system=system, model=model or "claude-3-5-sonnet-20240620")
    elif provider == "openai":
        return call_openai(prompt, system=system, model=model or "gpt-4o")
    else:
        raise ValueError(f"Unknown provider: {provider}")

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Simple LLM Client")
    parser.add_argument("prompt", help="The user prompt")
    parser.add_argument("--system", help="System prompt")
    parser.add_argument("--provider", default="anthropic", choices=["anthropic", "openai"], help="LLM Provider")
    parser.add_argument("--model", help="Specific model name")

    args = parser.parse_args()

    try:
        result = complete(args.prompt, provider=args.provider, system=args.system, model=args.model)
        print(result)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
