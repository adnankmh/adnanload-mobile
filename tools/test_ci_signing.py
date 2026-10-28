"""Self-contained tests for CI signing without Flutter or real signing secrets."""
from pathlib import Path
import base64
import tempfile
import unittest
from configure_ci_signing import configure, SIGNING_ENV

class SigningConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        app = self.root/'android/app'
        app.mkdir(parents=True)
        (app/'build.gradle.kts').write_text('''plugins { id("com.android.application") }
android {
    defaultConfig { minSdk = flutter.minSdkVersion }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
''',encoding='utf-8')

    def test_no_secrets_does_not_change_scaffold(self):
        gradle=self.root/'android/app/build.gradle.kts'
        before=gradle.read_bytes()
        self.assertEqual(configure({},self.root),'debug-key')
        self.assertEqual(gradle.read_bytes(),before)

    def test_incomplete_secrets_fail(self):
        with self.assertRaisesRegex(RuntimeError,'Incomplete'):
            configure({SIGNING_ENV[0]:'abc'},self.root)

    def test_invalid_base64_fails(self):
        with self.assertRaisesRegex(RuntimeError,'base64'):
            configure({name:'x' for name in SIGNING_ENV},self.root)

    def test_configuration_is_idempotent(self):
        env={
            SIGNING_ENV[0]:base64.b64encode(b'test keystore bytes'*4).decode(),
            SIGNING_ENV[1]:'testpass',SIGNING_ENV[2]:'testpass',SIGNING_ENV[3]:'testkey',
        }
        self.assertEqual(configure(env,self.root),'production-key')
        gradle=self.root/'android/app/build.gradle.kts'
        once=gradle.read_bytes()
        self.assertEqual(configure(env,self.root),'production-key')
        self.assertEqual(gradle.read_bytes(),once)
        self.assertIn('signingConfigs.getByName("adnanloadRelease")',gradle.read_text())
        self.assertTrue((self.root/'android/key.properties').exists())

if __name__ == '__main__':
    unittest.main(verbosity=2)
