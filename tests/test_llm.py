import unittest
from unittest.mock import patch, MagicMock
import os
from scripts import llm

class TestLLM(unittest.TestCase):
    @patch('scripts.llm.urllib.request.urlopen')
    @patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"})
    def test_call_anthropic_timeout(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.read.return_value = b'{"content": [{"text": "response"}]}'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        llm.call_anthropic("hello")

        mock_urlopen.assert_called_once()
        _, kwargs = mock_urlopen.call_args
        self.assertEqual(kwargs.get('timeout'), 60)

    @patch('scripts.llm.urllib.request.urlopen')
    @patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"})
    def test_call_openai_timeout(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.read.return_value = b'{"choices": [{"message": {"content": "response"}}]}'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        llm.call_openai("hello")

        mock_urlopen.assert_called_once()
        _, kwargs = mock_urlopen.call_args
        self.assertEqual(kwargs.get('timeout'), 60)

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

if __name__ == '__main__':
    unittest.main()
