"""Run the real Android Gradle patcher against a minimal fixture, twice.

No Flutter or Android SDK is required; this tests ONLY the Python patcher.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ORIGIN=Path(__file__).resolve().parents[1]

class AndroidConfigurationTests(unittest.TestCase):
    def test_android_gradle_idempotent_configuration(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/'tools').mkdir(parents=True)
            (root/'tools/configure_android.py').write_bytes((ORIGIN/'tools/configure_android.py').read_bytes())
            for source in (ORIGIN/'assets/android_icons').rglob('*.png'):
                dest=root/source.relative_to(ORIGIN)
                dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(source,dest)
            for source in (ORIGIN/'platform_overrides').rglob('*.xml'):
                dest=root/source.relative_to(ORIGIN)
                dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(source,dest)
            app=root/'android/app'
            (app/'src/main').mkdir(parents=True)
            (app/'src/main/AndroidManifest.xml').write_text('<manifest/>',encoding='utf-8')
            (app/'build.gradle.kts').write_text('''plugins { id("com.android.application") }
android { defaultConfig { minSdk = flutter.minSdkVersion }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17 }
}
''',encoding='utf-8')
            (root/'android/build.gradle.kts').write_text('''allprojects {
  repositories { google(); mavenCentral() }
}
''',encoding='utf-8')
            (root/'android/settings.gradle.kts').write_text('''plugins { id("org.jetbrains.kotlin.android") version "2.0.20" apply false }
''',encoding='utf-8')
            for _ in range(2):
                subprocess.run([sys.executable,str(root/'tools/configure_android.py')],check=True,
                               stdout=subprocess.DEVNULL)
            text=(app/'build.gradle.kts').read_text()
            gradle=(root/'android/build.gradle.kts').read_text()
            self.assertIn('minSdk = 24',text)
            self.assertEqual(text.count('coreLibraryDesugaring('),1)
            self.assertEqual(text.count('isCoreLibraryDesugaringEnabled'),1)
            self.assertEqual(gradle.count('https://jitpack.io'),1)
            self.assertIn('version "2.1.0"',(root/'android/settings.gradle.kts').read_text())
            manifest=(app/'src/main/AndroidManifest.xml').read_text()
            self.assertIn('FOREGROUND_SERVICE_DATA_SYNC',manifest)
            self.assertIn('UIDTJobService',manifest)
            ET.parse(app/'src/main/AndroidManifest.xml')
            for lang in ('values','values-ar'):
                resource=app/'src/main/res'/lang/'strings.xml'
                self.assertTrue(resource.exists())
                ET.parse(resource)
            self.assertEqual(len(list((app/'src/main/res').rglob('ic_launcher.png'))),5)

if __name__=='__main__':
    unittest.main(verbosity=2)
