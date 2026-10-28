"""Optional GitHub Release APK signing, without publishing keys in source."""
import base64
import binascii
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIGNING_ENV = (
    'ADNANLOAD_KEYSTORE_BASE64', 'ADNANLOAD_STORE_PASSWORD',
    'ADNANLOAD_KEY_PASSWORD', 'ADNANLOAD_KEY_ALIAS',
)


def configure(env=None, root=ROOT):
    env = os.environ if env is None else env
    root = Path(root)
    values = [env.get(key, '').strip() for key in SIGNING_ENV]
    if not any(values):
        print('::warning::No production signing secrets. Release-mode APK uses a temporary debug certificate, suitable for installation/testing only.')
        return 'debug-key'
    if not all(values):
        missing = [name for name, value in zip(SIGNING_ENV, values) if not value]
        raise RuntimeError('Incomplete signing configuration, missing: ' + ', '.join(missing))

    data_b64, store_password, key_password, key_alias = values
    try:
        keystore = base64.b64decode(''.join(data_b64.split()), validate=True)
    except (binascii.Error, ValueError) as exc:
        raise RuntimeError('ADNANLOAD_KEYSTORE_BASE64 is not valid base64') from exc
    if len(keystore) < 32:
        raise RuntimeError('The decoded signing keystore is implausibly small')
    if any('\n' in v or '\r' in v for v in (store_password, key_password, key_alias)):
        raise RuntimeError('Signing passwords and alias may not contain line breaks')

    app = root / 'android/app'
    gradle = app / 'build.gradle.kts'
    if not gradle.is_file():
        raise RuntimeError('Android Kotlin Gradle missing; run flutter create first')

    store_path = app/'adnanload-ci-release.jks'
    store_path.write_bytes(keystore)
    props = root/'android/key.properties'
    props.write_text('\n'.join([
        f'storePassword={store_password}',
        f'keyPassword={key_password}',
        f'keyAlias={key_alias}',
        f'storeFile={store_path.as_posix()}',
    ])+'\n', encoding='utf-8')

    content = gradle.read_text(encoding='utf-8')
    if '// ADNANLOAD CI RELEASE SIGNING' in content:
        print('Gradle signing already configured.')
        return 'production-key'
    if 'android {' not in content or '    buildTypes {' not in content:
        raise RuntimeError('Unexpected Android Gradle structure; refusing signing patch')
    old = 'signingConfig = signingConfigs.getByName("debug")'
    if old not in content:
        raise RuntimeError('Expected debug signing configuration absent; refusing unsafe patch')

    content = 'import java.io.FileInputStream\nimport java.util.Properties\n\n' + content
    content = content.replace('android {', '''// ADNANLOAD CI RELEASE SIGNING
val adnanloadKeystoreProperties = Properties()
val adnanloadKeystoreFile = rootProject.file("key.properties")
adnanloadKeystoreProperties.load(FileInputStream(adnanloadKeystoreFile))

android {''', 1)
    content = content.replace('    buildTypes {', '''    signingConfigs {
        create("adnanloadRelease") {
            keyAlias = adnanloadKeystoreProperties.getProperty("keyAlias")
            keyPassword = adnanloadKeystoreProperties.getProperty("keyPassword")
            storeFile = file(adnanloadKeystoreProperties.getProperty("storeFile"))
            storePassword = adnanloadKeystoreProperties.getProperty("storePassword")
        }
    }
    buildTypes {''', 1)
    content = content.replace(old, 'signingConfig = signingConfigs.getByName("adnanloadRelease")', 1)
    gradle.write_text(content, encoding='utf-8')
    print('Production signing configured via GitHub Actions secrets.')
    return 'production-key'


if __name__ == '__main__':
    mode = configure()
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a', encoding='utf-8') as handle:
            handle.write('mode=' + mode + '\n')
