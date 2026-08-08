#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.error

# Unified LLM Client for Agent Harness

def call_anthropic(prompt, system=None, model="claude-3-5-sonnet-20240620", api_key=None, timeout=60):
    """Calls Anthropic's Messages API with streaming."""
    api_key = api_key or os.getenv("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_API_KEY")
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
        "messages": messages,
        "stream": True
    }

    if system:
        data["system"] = system

    req = urllib.request.Request(url, json.dumps(data).encode("utf-8"), headers)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            for line_bytes in response:
                line = line_bytes.decode("utf-8").strip()
                if line.startswith("data: ") and line != "data: [DONE]":
                    data_str = line[6:]
                    try:
                        event = json.loads(data_str)
                        if event.get("type") == "error":
                            err = event.get("error", {})
                            raise Exception(f"Anthropic API Error in stream: {err.get('message')}")
                        if event.get("type") == "content_block_delta":
                            delta = event.get("delta", {})
                            if delta.get("type") == "text_delta":
                                print(delta.get("text", ""), end="", flush=True)
                    except json.JSONDecodeError:
                        # Anthropic sometimes sends invalid JSON like partial chunks, but typically SSE is well-formed
                        pass
            print() # Print final newline
            return None
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        raise Exception(f"Anthropic API Error: {e.code} - {err_body}")
    except urllib.error.URLError as e:
        raise Exception(f"Anthropic API Connection Error: {e.reason}")

def call_openai(prompt, system=None, model="gpt-4o", api_key=None, timeout=60):
    """Calls OpenAI's Chat Completion API with streaming."""
    api_key = api_key or os.getenv("OPENAI_API_KEY") or os.environ.get("OPENAI_API_KEY")
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
        "messages": messages,
        "stream": True
    }

    req = urllib.request.Request(url, json.dumps(data).encode("utf-8"), headers)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            for line_bytes in response:
                line = line_bytes.decode("utf-8").strip()
                if line.startswith("data: ") and line != "data: [DONE]":
                    data_str = line[6:]
                    try:
                        event = json.loads(data_str)
                        choices = event.get("choices", [])
                        if choices:
                            delta = choices[0].get("delta", {})
                            content = delta.get("content")
                            if content:
                                print(content, end="", flush=True)
                    except json.JSONDecodeError:
                        pass
            print() # Print final newline
            return None
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        raise Exception(f"OpenAI API Error: {e.code} - {err_body}")
    except urllib.error.URLError as e:
        raise Exception(f"OpenAI API Connection Error: {e.reason}")

def complete(prompt, provider="anthropic", system=None, model=None, timeout=60):
    """Unified completion function."""

    # Provider selection logic
    if provider == "anthropic":
        return call_anthropic(prompt, system=system, model=model or "claude-3-5-sonnet-20240620", timeout=timeout)
    elif provider == "openai":
        return call_openai(prompt, system=system, model=model or "gpt-4o", timeout=timeout)
    else:
        raise ValueError(f"Unknown provider: {provider}")

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Simple LLM Client")
    parser.add_argument("prompt", help="The user prompt")
    parser.add_argument("--system", help="System prompt")
    parser.add_argument("--provider", default="anthropic", choices=["anthropic", "openai"], help="LLM Provider")
    parser.add_argument("--model", help="Specific model name")
    parser.add_argument("--timeout", type=float, default=60.0, help="Timeout in seconds")

    args = parser.parse_args()

    try:
        result = complete(args.prompt, provider=args.provider, system=args.system, model=args.model, timeout=args.timeout)
        if result is not None:
            print(result)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
