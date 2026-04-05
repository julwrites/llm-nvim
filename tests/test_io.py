import unittest
import os
import json
import shutil
from scripts.lib import io

class TestAtomicIO(unittest.TestCase):
    def setUp(self):
        self.test_dir = "tests/tmp_io"
        os.makedirs(self.test_dir, exist_ok=True)

    def tearDown(self):
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_write_read_text(self):
        filepath = os.path.join(self.test_dir, "test.txt")
        content = "Hello World"
        io.write_atomic(filepath, content)
        self.assertEqual(io.read_text(filepath), content)

    def test_write_read_json(self):
        filepath = os.path.join(self.test_dir, "test.json")
        data = {"key": "value", "list": [1, 2, 3]}
        io.write_json(filepath, data)
        self.assertEqual(io.read_json(filepath), data)

    def test_overwrite(self):
        filepath = os.path.join(self.test_dir, "overwrite.txt")
        io.write_atomic(filepath, "v1")
        self.assertEqual(io.read_text(filepath), "v1")
        io.write_atomic(filepath, "v2")
        self.assertEqual(io.read_text(filepath), "v2")

if __name__ == '__main__':
    unittest.main()
