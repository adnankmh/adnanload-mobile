import unittest
from version_policy import supported_version

class VersionTests(unittest.TestCase):
    def test_supported_versions(self):
        for version in ('2.1.0+10', '2.1.1+11', '2.2.0+1', '3.0.0+1'):
            with self.subTest(version=version):
                self.assertTrue(supported_version(f'name: app\nversion: {version}\n'))
    def test_invalid_and_older_versions(self):
        for version in ('0.0.1+1', '2.0.9+999', '2.1.0+9', 'garbage', '2.1.1'):
            with self.subTest(version=version):
                self.assertFalse(supported_version(f'name: app\nversion: {version}\n'))

if __name__ == '__main__':
    unittest.main(verbosity=2)
