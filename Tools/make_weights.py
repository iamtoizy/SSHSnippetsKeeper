#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_weights.py - сборка файла весов scripts_weights.bin для автоопределения
языка сниппетов в SSH Snippets Keeper (наивный Байес: bash / bat / powershell).

Полный аналог Delphi-тренера Tools\\LangNBTrainer.exe: формат файла весов
байт-в-байт совместим с приложением (магия SSKNBW01, 7-битная длина строк +
UTF-8 - как пишет Delphi TBinaryWriter).

ИСПОЛЬЗОВАНИЕ:
    python make_weights.py <bash_папка> <cmd_папка> <powershell_папка> [-o ФАЙЛ]
    python make_weights.py --inspect <scripts_weights.bin>

    bash_папка / cmd_папка / powershell_папка
        Папки с вашими коллекциями скриптов (обход рекурсивный).
    -o, --output
        Куда сохранить веса (по умолчанию: scripts_weights.bin в текущей папке).
    --prune N
        Порог чистки словарей: слова, встретившиеся суммарно реже N раз,
        удаляются (по умолчанию 3; для маленьких выборок поставьте 1).
    --inspect ФАЙЛ
        Не обучать, а показать содержимое готового файла весов.

КУДА ПОЛОЖИТЬ РЕЗУЛЬТАТ:
    scripts_weights.bin кладётся РЯДОМ С EXE приложения
    (либо в Assets\\ExeData при запуске из исходников).
    Веса читаются один раз при старте программы - после замены файла
    перезапустите приложение.

КАК СОБРАТЬ ВЕСА ПРАВИЛЬНО (см. также README_make_weights.md):
    1. Три папки, по одной на язык. Имена папок любыми, вложенность любая.
    2. Расширения фильтруются автоматически:
       bash: .sh/.bash; cmd: .bat/.cmd; powershell: .ps1/.psm1.
       Если по расширениям не нашлось ничего - берутся все файлы папки.
    3. Идеально: 50-300 файлов НА ЯЗЫК, разных по тематике и стилю.
       Минимум, при котором детект осмысленен: ~20 файлов на язык.
    4. Стерильность: cmd/bash-файлы, вызывающие powershell/pwsh,
       исключаются автоматически (иначе токены PowerShell загрязнят
       профиль cmd). Не подкладывайте в папки чужие языки.
    5. Кодировка любая (UTF-8 с BOM/без, ANSI) - определяется автоматически.
"""

import argparse
import codecs
import os
import struct
import sys

MAGIC = b'SSKNBW01'
VERSION = 1
DEFAULT_OUTPUT = 'scripts_weights.bin'
PRUNE_THRESHOLD = 3
MIN_TOKEN_LEN = 2
MAX_TOKEN_LEN = 48

LANG_IDS = ['bash', 'bat', 'powershell']
LANG_EXTS = {
    'bash': ['.sh', '.bash'],
    'bat': ['.bat', '.cmd'],
    'powershell': ['.ps1', '.psm1'],
}
OP_CHARS = '|&<>!'


# ---------------------------------------------------------------- токенизатор

def _is_word_char(c):
    """Слово: буквы/цифры + '_' + приклеенные '-' и '$'; не-ASCII - буквы/цифры."""
    if ('a' <= c <= 'z') or ('A' <= c <= 'Z') or ('0' <= c <= '9') \
            or c == '_' or c == '-' or c == '$':
        return True
    return ord(c) >= 128 and c.isalnum()


def tokenize(text):
    """Аналог ForEachToken: слова (нижний регистр, обрезка до 48, минимум 2)
    и операторные последовательности (|, ||, &&, >>, >& из 2>&1) как токены."""
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in OP_CHARS:
            j = i
            while j < n and text[j] in OP_CHARS:
                j += 1
            yield text[i:j]
            i = j
            continue
        if _is_word_char(c):
            buf = []
            while i < n and _is_word_char(text[i]):
                if len(buf) < MAX_TOKEN_LEN:
                    buf.append(text[i].lower())
                i += 1
            if len(buf) >= MIN_TOKEN_LEN:
                yield ''.join(buf)
            continue
        i += 1


# ------------------------------------------------------------------- обучение

class LangModel:
    def __init__(self, name):
        self.name = name
        self.doc_count = 0
        self.total_tokens = 0
        self.words = {}  # word -> [count, docfreq]


def train_text(model, text):
    doc_tf = {}
    for token in tokenize(text):
        doc_tf[token] = doc_tf.get(token, 0) + 1
    if not doc_tf:
        return
    model.doc_count += 1
    for word, cnt in doc_tf.items():
        stat = model.words.get(word)
        if stat is None:
            model.words[word] = [cnt, 1]
        else:
            stat[0] += cnt
            stat[1] += 1
    model.total_tokens += sum(doc_tf.values())


def prune_rare(model, min_occurrences):
    dead = [w for w, (cnt, _df) in model.words.items() if cnt < min_occurrences]
    for w in dead:
        del model.words[w]
    model.total_tokens = sum(cnt for cnt, _df in model.words.values())


# ------------------------------------------------------------------- файлы

def is_power_shell_wrapper(text):
    up = text.upper()
    return 'POWERSHELL' in up or 'PWSH' in up


def read_text(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data.startswith(codecs.BOM_UTF8):
        return data[3:].decode('utf-8', 'replace')
    if data.startswith(codecs.BOM_UTF16_LE) or data.startswith(codecs.BOM_UTF16_BE):
        return data.decode('utf-16', 'replace')
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        return data.decode(locale_encoding(), 'replace')


def locale_encoding():
    try:
        import locale
        enc = locale.getpreferredencoding(False)
        return enc or 'cp1252'
    except Exception:
        return 'cp1252'


def collect_scripts(folder, exts):
    matched, all_files = [], []
    for root, _dirs, files in os.walk(folder):
        for name in files:
            path = os.path.join(root, name)
            all_files.append(path)
            if os.path.splitext(name)[1].lower() in exts:
                matched.append(path)
    if not matched and all_files:
        print('WARNING: {}: по расширениям не нашлось ничего, '
              'берутся все {} файлов (проверьте порядок аргументов)'.format(
                  folder, len(all_files)))
        return all_files
    return matched


# ------------------------------------------------------- сериализация (Delphi)

def _w7(f, n):
    """7-битная кодировка длины - как Delphi TBinaryWriter.Write(string)."""
    while n >= 0x80:
        f.write(bytes([(n & 0x7F) | 0x80]))
        n >>= 7
    f.write(bytes([n]))


def _r7(f):
    n, shift = 0, 0
    while True:
        b = f.read(1)[0]
        n |= (b & 0x7F) << shift
        if not (b & 0x80):
            return n
        shift += 7


def _wstr(f, s):
    raw = s.encode('utf-8')
    _w7(f, len(raw))
    f.write(raw)


def _rstr(f):
    return f.read(_r7(f)).decode('utf-8')


def save_weights(path, models):
    folder = os.path.dirname(os.path.abspath(path))
    os.makedirs(folder, exist_ok=True)
    with open(path, 'wb') as f:
        f.write(MAGIC)
        f.write(struct.pack('<i', VERSION))
        f.write(struct.pack('<i', len(models)))
        for model in models:
            _wstr(f, model.name)
            f.write(struct.pack('<q', model.doc_count))
            f.write(struct.pack('<q', model.total_tokens))
            f.write(struct.pack('<i', len(model.words)))
            for word, (cnt, doc_freq) in model.words.items():
                _wstr(f, word)
                f.write(struct.pack('<q', cnt))
                f.write(struct.pack('<q', doc_freq))


def load_weights(path):
    """Чтение файла весов (для --inspect и самопроверки)."""
    models = []
    with open(path, 'rb') as f:
        if f.read(len(MAGIC)) != MAGIC:
            raise ValueError('неверная магия файла (не SSKNBW01)')
        version, = struct.unpack('<i', f.read(4))
        if version != VERSION:
            raise ValueError('неподдерживаемая версия формата: {}'.format(version))
        n_langs, = struct.unpack('<i', f.read(4))
        for _ in range(n_langs):
            name = _rstr(f)
            model = LangModel(name)
            model.doc_count, = struct.unpack('<q', f.read(8))
            model.total_tokens, = struct.unpack('<q', f.read(8))
            n_words, = struct.unpack('<i', f.read(4))
            for _ in range(n_words):
                word = _rstr(f)
                cnt, doc_freq = struct.unpack('<qq', f.read(16))
                model.words[word] = [cnt, doc_freq]
            models.append(model)
    return models


def inspect_weights(path):
    models = load_weights(path)
    for model in models:
        print('  {:<10} docs={:<5} vocab={:<5} total_tokens={}'.format(
            model.name, model.doc_count, len(model.words), model.total_tokens))
        top = sorted(model.words.items(), key=lambda kv: -kv[1][0])[:5]
        for word, (cnt, _df) in top:
            print('      {:<20} {}'.format(word, cnt))


# ----------------------------------------------------------------------- main

def build_arg_parser():
    parser = argparse.ArgumentParser(
        prog='make_weights.py',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description='Сборка scripts_weights.bin для автоопределения языка '
                    'сниппетов в SSH Snippets Keeper (bash/bat/powershell).',
        epilog='КАК СОБРАТЬ ПРАВИЛЬНО:\n'
               '  1. Три папки, по одной на язык; обход рекурсивный.\n'
               '  2. Расширения: bash .sh/.bash; cmd .bat/.cmd; powershell .ps1/.psm1\n'
               '     (если по расширениям пусто - берутся все файлы папки).\n'
               '  3. Идеально 50-300 файлов НА ЯЗЫК, разнообразных по темам;\n'
               '     минимум ~20. Больше данных - точнее определение.\n'
               '  4. cmd/bash-файлы с вызовом powershell/pwsh исключаются\n'
               '     автоматически (стерильность обучающей выборки).\n'
               '  5. Готовый scripts_weights.bin положите РЯДОМ С EXE программы\n'
               '     (или в Assets\\ExeData при запуске из исходников) и\n'
               '     перезапустите приложение - веса читаются при старте.\n'
               'Проверить готовый файл: python make_weights.py --inspect файл\n')
    parser.add_argument('folders', nargs='*', metavar='folder',
                        help='папки: <bash> <cmd> <powershell>')
    parser.add_argument('-o', '--output', default=DEFAULT_OUTPUT,
                        help='файл весов (по умолчанию: %(default)s)')
    parser.add_argument('--prune', type=int, default=PRUNE_THRESHOLD,
                        help='порог чистки редких слов (по умолчанию: %(default)s)')
    parser.add_argument('--inspect', metavar='FILE',
                        help='показать содержимое файла весов и выйти')
    return parser


def main(argv=None):
    if sys.stdout.encoding and sys.stdout.encoding.lower().replace('-', '') != 'utf8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except Exception:
            pass

    parser = build_arg_parser()
    args = parser.parse_args(argv)

    if args.inspect:
        inspect_weights(args.inspect)
        return 0

    if len(args.folders) != 3:
        parser.print_usage()
        print('\nОшибка: укажите ровно три папки: <bash> <cmd> <powershell>')
        return 2

    folders = []
    for folder in args.folders:
        if not os.path.isdir(folder):
            print('ERROR: папка не найдена: {}'.format(folder))
            return 2
        folders.append(folder)

    models = {}
    docs = {'bash': 0, 'bat': 0, 'powershell': 0}
    skipped = {'bash': 0, 'bat': 0, 'powershell': 0}

    for lang_id, folder in zip(LANG_IDS, folders):
        files = collect_scripts(folder, LANG_EXTS[lang_id])
        for path in files:
            text = read_text(path)
            if lang_id != 'powershell' and is_power_shell_wrapper(text):
                skipped[lang_id] += 1
                continue
            model = models.setdefault(lang_id, LangModel(lang_id))
            before = model.doc_count
            train_text(model, text)
            if model.doc_count > before:
                docs[lang_id] += 1

    for model in models.values():
        prune_rare(model, args.prune)

    ordered = [models[lang] for lang in LANG_IDS if lang in models]
    save_weights(args.output, ordered)

    print('Обучена наивная Байес модель:')
    for lang_id in LANG_IDS:
        model = models.get(lang_id)
        vocab = len(model.words) if model else 0
        print('  {:<10} docs={:<5} vocab={:<5} skipped(wrapper)={}'.format(
            lang_id, docs[lang_id], vocab, skipped[lang_id]))
    print('Порог чистки   : {}'.format(args.prune))
    print('Веса сохранены : {}'.format(os.path.abspath(args.output)))

    # Самопроверка: перечитываем файл и сверяем структуру
    check = load_weights(args.output)
    for model in ordered:
        loaded = next(m for m in check if m.name == model.name)
        assert loaded.doc_count == model.doc_count
        assert loaded.total_tokens == model.total_tokens
        assert loaded.words == model.words
    print('Самопроверка файла: OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
