import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/batch_links.dart';

void main(){
  test('only unique public safe links are accepted',(){
    final links=BatchLinks.parse('''
https://example.org/one.zip
https://example.org/one.zip
http://127.0.0.1/admin
file:///etc/passwd
https://example.org/two.pdf
''');
    expect(links,['https://example.org/one.zip','https://example.org/two.pdf']);
  });
  test('existing downloads filtered, limit enforced',(){
    final text=List.generate(120,(i)=>'https://example.net/f/$i').join('\n');
    expect(BatchLinks.parse(text).length,BatchLinks.maxLinks);
    expect(BatchLinks.parse('https://example.org/one.zip',existing:{'https://example.org/one.zip'}),isEmpty);
  });
}
