import os
import sys

os.chdir(os.path.join(os.path.dirname(__file__), '../'))

# Windows CI 控制台默认编码不是 UTF-8，直接 print 中文会抛 UnicodeEncodeError
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

if __name__ == '__main__':
    with open('./CHANGELOG.md', 'r', encoding='utf-8') as file:
        log = file.read()

    start_index = log.find('# v')
    end_index = log.find('# v', start_index + 1)
    if start_index == -1:
        raise SystemExit('CHANGELOG.md 里找不到以 "# v" 开头的版本段')
    change_latest = log[start_index:] if end_index == -1 else log[start_index:end_index]

    with open('CHANGELATEST.md', 'w', encoding='utf-8', newline='\n') as file:
        file.write(change_latest)

    print(change_latest)
    print(f'[CHANGELATEST.md] 已生成，{len(change_latest)} 字符')
