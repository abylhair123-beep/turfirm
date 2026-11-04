#!/usr/bin/env python3
"""Скрипт создания резервных копий PostgreSQL с сжатием и выгрузкой в S3.

Поддерживает:
- Создание сжатого дампа БД через pg_dump + gzip
- Выгрузку в S3 / MinIO (boto3)
- Сохранение локальных копий в backups/
- Ротацию бэкапов (удаление старше заданного retention period, по умолчанию 7 дней)
- Запуск по расписанию через cron или Docker-контейнер
"""

import argparse
from datetime import datetime, timezone, timedelta
import gzip
import logging
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urlparse

import boto3
from botocore.client import Config

# Добавляем корневую директорию backend в sys.path для импорта config
_backend_dir = Path(__file__).resolve().parent.parent
if str(_backend_dir) not in sys.path:
    sys.path.insert(0, str(_backend_dir))

from app.core.config import settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("sapar.backup")


def parse_db_url(url: str):
    """Извлекает параметры подключения к базе из DATABASE_URL."""
    # Удаляем префикс драйвера, например postgresql+psycopg2:// -> postgresql://
    normalized = url.replace("postgresql+psycopg2://", "postgresql://")
    parsed = urlparse(normalized)
    return {
        "user": parsed.username or "sapar",
        "password": parsed.password or "sapar_secret",
        "host": parsed.hostname or "localhost",
        "port": parsed.port or 5432,
        "dbname": parsed.path.lstrip("/") or "sapar",
    }


def get_s3_client():
    """Создаёт клиент boto3 для S3 / MinIO, если учетные данные заданы."""
    access_key = settings.s3_access_key
    secret_key = settings.s3_secret_key
    bucket = settings.backup_s3_bucket or settings.s3_bucket

    if not access_key or not secret_key:
        return None, bucket

    endpoint = settings.backup_s3_endpoint_url or settings.s3_endpoint_url
    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name=settings.s3_region,
        config=Config(signature_version="s3v4"),
        use_ssl=settings.s3_use_ssl,
    )
    return client, bucket


def create_local_dump(output_path: Path, db_params: dict) -> bool:
    """Выполняет pg_dump базы данных и сжимает результат gzip."""
    logger.info(f"Создание дампа базы данных '{db_params['dbname']}' с хоста {db_params['host']}:{db_params['port']}...")
    
    env = os.environ.copy()
    if db_params.get("password"):
        env["PGPASSWORD"] = str(db_params["password"])

    pg_dump_cmd = [
        "pg_dump",
        "-h", str(db_params["host"]),
        "-p", str(db_params["port"]),
        "-U", str(db_params["user"]),
        "-d", str(db_params["dbname"]),
        "--no-owner",
        "--no-acl",
    ]

    try:
        # Проверяем наличие утилиты pg_dump в PATH
        if not shutil.which("pg_dump"):
            logger.warning("Утилита pg_dump не найдена в системном PATH. Попытка резервирования через python / docker...")
            # Если запущено на хосте без pg_dump, пробуем выполнить дамп через docker exec sapar_postgres
            docker_cmd = [
                "docker", "exec", "-e", f"PGPASSWORD={db_params['password']}",
                "sapar_postgres",
                "pg_dump", "-U", str(db_params["user"]), "-d", str(db_params["dbname"]),
                "--no-owner", "--no-acl"
            ]
            process = subprocess.Popen(docker_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            process = subprocess.Popen(pg_dump_cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        with gzip.open(output_path, "wb") as gz_file:
            shutil.copyfileobj(process.stdout, gz_file)

        _, stderr = process.communicate()
        if process.returncode != 0:
            logger.error(f"Ошибка pg_dump: {stderr.decode('utf-8', errors='ignore')}")
            if output_path.exists():
                output_path.unlink()
            return False

        size_kb = output_path.stat().st_size / 1024
        logger.info(f"Дамп успешно создан: {output_path} ({size_kb:.1f} KB)")
        return True

    except Exception as e:
        logger.error(f"Критическая ошибка создания дампа: {e}")
        if output_path.exists():
            output_path.unlink()
        return False


def upload_to_s3(client, bucket: str, local_path: Path, s3_key: str) -> bool:
    """Загружает файл бэкапа в бакет S3."""
    try:
        logger.info(f"Загрузка бэкапа в S3: s3://{bucket}/{s3_key}...")
        client.upload_file(str(local_path), bucket, s3_key)
        logger.info("Загрузка в S3 завершена успешно.")
        return True
    except Exception as e:
        logger.error(f"Не удалось выгрузить бэкап в S3: {e}")
        return False


def rotate_backups(local_dir: Path, s3_client, bucket: str, retention_days: int):
    """Удаляет старые резервные копии из локальной директории и из S3."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
    logger.info(f"Ротация бэкапов: удаление копий старше {retention_days} дней (до {cutoff.strftime('%Y-%m-%d')})...")

    # 1. Локальная ротация
    if local_dir.exists():
        for file in local_dir.glob("sapar_backup_*.sql.gz"):
            try:
                mtime = datetime.fromtimestamp(file.stat().st_mtime, tz=timezone.utc)
                if mtime < cutoff:
                    file.unlink()
                    logger.info(f"Удален устаревший локальный бэкап: {file.name}")
            except Exception as e:
                logger.warning(f"Не удалось проверить/удалить {file}: {e}")

    # 2. Ротация в S3
    if s3_client and bucket:
        try:
            prefix = settings.backup_s3_prefix.strip("/")
            resp = s3_client.list_objects_v2(Bucket=bucket, Prefix=f"{prefix}/")
            contents = resp.get("Contents", [])
            for obj in contents:
                key = obj.get("Key", "")
                last_mod = obj.get("LastModified")
                if last_mod and last_mod < cutoff:
                    s3_client.delete_object(Bucket=bucket, Key=key)
                    logger.info(f"Удален устаревший бэкап из S3: s3://{bucket}/{key}")
        except Exception as e:
            logger.warning(f"Ошибка при очистке устаревших бэкапов в S3: {e}")


def run_backup(retention_days: int = 7) -> bool:
    """Полный цикл создания резервной копии и очистки."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"sapar_backup_{timestamp}.sql.gz"

    local_dir = _backend_dir / settings.backup_local_dir
    local_dir.mkdir(parents=True, exist_ok=True)
    local_path = local_dir / filename

    db_params = parse_db_url(settings.database_url)
    success = create_local_dump(local_path, db_params)

    if not success:
        logger.error("Процесс резервного копирования завершился с ошибкой.")
        return False

    s3_client, bucket = get_s3_client()
    if s3_client and bucket:
        prefix = settings.backup_s3_prefix.strip("/")
        s3_key = f"{prefix}/{filename}"
        upload_to_s3(s3_client, bucket, local_path, s3_key)
    else:
        logger.info("Учетные данные S3 не заданы. Бэкап сохранен только локально.")

    rotate_backups(local_dir, s3_client, bucket, retention_days)
    logger.info("Резервное копирование успешно завершено!")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="SAPAR PostgreSQL Database Backup Utility")
    parser.add_argument("--retention-days", type=int, default=settings.backup_retention_days, help="Дней хранения бэкапов")
    args = parser.parse_args()

    ok = run_backup(retention_days=args.retention_days)
    sys.exit(0 if ok else 1)
