#!/usr/bin/env python3
import os
import sys
from pathlib import Path
import logging
from typing import Dict, List, Tuple
from dotenv import dotenv_values

# ロギングの設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def convert_to_shell_format(key: str, value: str, comment: str = None) -> str:
    """
    環境変数をシェルスクリプト形式に変換します。

    Args:
        key (str): 変数名
        value (str): 値
        comment (str, optional): コメント

    Returns:
        str: シェルスクリプト形式の行
    """
    if not key:
        return f"# {comment}" if comment else ""

    # 値が None の場合は空文字列として扱う
    if value is None:
        value = ""

    # 値をエスケープして引用符で囲む
    value_str = str(value)
    if any(c in value_str for c in ' \'"$#\\') or value_str.lower() in ['true', 'false', 'null', 'none']:
        # ダブルクォート内の特殊文字をエスケープ
        escaped_value = value_str.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$')
        value_str = f'"{escaped_value}"'
    elif not value_str:
        value_str = '""'

    comment_part = f" # {comment}" if comment else ""
    return f'export {key}={value_str}{comment_part}'

def process_env_file(input_path: Path, output_path: Path = None) -> List[str]:
    """
    .env ファイルを処理してシェルスクリプト形式の行のリストを生成します。

    Args:
        input_path (Path): 入力ファイルのパス

    Returns:
        List[str]: シェルスクリプト形式の行のリスト
    """
    output_lines = [
        '#!/bin/bash',
        f'# このファイルは convert_env.py により自動生成されました',
        f'# 元ファイル: {input_path.name}',
        ''
    ]

    # dotenv_values は OrderedDict を返し、コメントも保持します
    env_dict = dotenv_values(input_path)

    # ファイルを読み込んでコメントブロックを抽出
    with input_path.open('r', encoding='utf-8') as f:
        lines = f.readlines()

    # コメントブロックを処理
    current_comment_block = []
    for line in lines:
        line = line.strip()
        if not line:
            if current_comment_block:
                output_lines.extend(current_comment_block)
                current_comment_block = []
            output_lines.append('')
        elif line.startswith('#'):
            current_comment_block.append(line)
        else:
            if current_comment_block:
                output_lines.extend(current_comment_block)
                current_comment_block = []
            
            # 変数定義行を探す
            if '=' in line:
                key = line.split('=', 1)[0].strip()
                if key in env_dict:
                    # コメントを抽出（行末のコメント）
                    comment = None
                    if '#' in line:
                        comment = line[line.find('#')+1:].strip()
                    
                    # 環境変数を変換
                    output_lines.append(convert_to_shell_format(key, env_dict[key], comment))

    # 最後のコメントブロックを追加
    if current_comment_block:
        output_lines.extend(current_comment_block)

    return output_lines

def load_env_file(input_path: Path, apply_to_env: bool = True) -> Dict[str, str]:
    """
    .env ファイルを読み込み、必要に応じて環境変数として設定します。

    Args:
        input_path (Path): 入力ファイルのパス
        apply_to_env (bool): 環境変数として設定するかどうか

    Returns:
        Dict[str, str]: 読み込んだ環境変数の辞書
    """
    if not input_path.exists():
        raise FileNotFoundError(f"指定されたファイルが見つかりません: {input_path}")

    if not input_path.name.startswith('.env'):
        raise ValueError(f"入力ファイル {input_path.name} は .env で始まっていません")

    env_dict = dotenv_values(input_path)
    
    if apply_to_env:
        for key, value in env_dict.items():
            if value is not None:  # None の場合は設定しない
                os.environ[key] = str(value)
    
    return env_dict

def convert_env_file(input_path: Path, output_path: Path = None) -> Path:
    """
    .env ファイルを env.sh に変換します。

    Args:
        input_path (Path): 入力ファイルのパス
        output_path (Path, optional): 出力ファイルのパス。指定がない場合は同じディレクトリの env.sh

    Returns:
        Path: 生成されたファイルのパス
    """
    if output_path is None:
        output_path = input_path.parent / 'env.sh'

    # 環境変数ファイルを処理
    output_lines = process_env_file(input_path)

    # 結果を書き込み
    with output_path.open('w', encoding='utf-8') as f:
        f.write('\n'.join(output_lines))
        f.write('\n')  # 最後の改行を追加

    # 実行権限を付与
    os.chmod(output_path, 0o755)

    logger.info(f"環境変数ファイルを変換しました")
    logger.info(f"入力ファイル: {input_path}")
    logger.info(f"出力ファイル: {output_path}")

    return output_path

def main():
    """
    メイン処理：コマンドライン引数を処理し、環境変数ファイルを変換します。
    """
    if len(sys.argv) != 2:
        logger.error("使用方法: uv run convert_env.py <.env ファイルのパス>")
        logger.error("例: uv run convert_env.py ../5.mlflow/.env.example")
        sys.exit(1)

    try:
        input_path = Path(sys.argv[1])
        convert_env_file(input_path)
    except Exception as e:
        logger.error(f"エラーが発生しました: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
