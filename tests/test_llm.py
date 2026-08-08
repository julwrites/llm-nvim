import unittest
from unittest.mock import patch, MagicMock
import os
import sys
import io
from scripts import llm

class TestLLM(unittest.TestCase):
    @patch('scripts.llm.urllib.request.urlopen')
    @patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"})
    def test_call_anthropic_timeout(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.__iter__.return_value = [
            b'data: {"type": "content_block_delta", "delta": {"type": "text_delta", "text": "response"}}\n'
        ]
        mock_urlopen.return_value.__enter__.return_value = mock_response

        # Capture stdout
        captured_output = io.StringIO()
        sys.stdout = captured_output

        llm.call_anthropic("hello", timeout=120)

        sys.stdout = sys.__stdout__

        mock_urlopen.assert_called_once()
        _, kwargs = mock_urlopen.call_args
        self.assertEqual(kwargs.get('timeout'), 120)
        self.assertEqual(captured_output.getvalue().strip(), "response")

    @patch('scripts.llm.urllib.request.urlopen')
    @patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"})
    def test_call_openai_timeout(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.__iter__.return_value = [
            b'data: {"choices": [{"delta": {"content": "response"}}]}\n'
        ]
        mock_urlopen.return_value.__enter__.return_value = mock_response

        # Capture stdout
        captured_output = io.StringIO()
        sys.stdout = captured_output

        llm.call_openai("hello", timeout=120)

        sys.stdout = sys.__stdout__

        mock_urlopen.assert_called_once()
        _, kwargs = mock_urlopen.call_args
        self.assertEqual(kwargs.get('timeout'), 120)
        self.assertEqual(captured_output.getvalue().strip(), "response")

    @patch('scripts.llm.urllib.request.urlopen')
    @patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"})
    def test_call_anthropic_urlerror(self, mock_urlopen):
        mock_urlopen.side_effect = llm.urllib.error.URLError("Connection refused")
        with self.assertRaisesRegex(Exception, "Anthropic API Connection Error: Connection refused"):
            llm.call_anthropic("hello")

    @patch('scripts.llm.urllib.request.urlopen')
    @patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"})
    def test_call_openai_urlerror(self, mock_urlopen):
        mock_urlopen.side_effect = llm.urllib.error.URLError("Connection refused")
        with self.assertRaisesRegex(Exception, "OpenAI API Connection Error: Connection refused"):
            llm.call_openai("hello")

    @patch('scripts.llm.urllib.request.urlopen')
    @patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"})
    def test_call_anthropic_stream_error(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.__iter__.return_value = [
            b'data: {"type": "error", "error": {"message": "Invalid request"}}\n'
        ]
        mock_urlopen.return_value.__enter__.return_value = mock_response

        with self.assertRaisesRegex(Exception, "Anthropic API Error in stream: Invalid request"):
            llm.call_anthropic("hello")

    @patch('scripts.llm.urllib.request.urlopen')
    @patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"})
    def test_call_openai_invalid_json(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.__iter__.return_value = [
            b'data: invalid json\n'
        ]
        mock_urlopen.return_value.__enter__.return_value = mock_response

        captured_output = io.StringIO()
        sys.stdout = captured_output

        # Should not raise exception, just ignore invalid json
        llm.call_openai("hello")

        sys.stdout = sys.__stdout__
        self.assertEqual(captured_output.getvalue().strip(), "")

if __name__ == '__main__':
    unittest.main()
