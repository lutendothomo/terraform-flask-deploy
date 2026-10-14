import sys
from pathlib import Path

# Ensure repository root is on sys.path when running this file directly
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import unittest
from app.app import app


class FlaskAppTestCase(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()

    def test_home(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data.decode("utf-8"), "terraform-flask-deploy is live")

    def test_health(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok"})


if __name__ == "__main__":
    unittest.main()
