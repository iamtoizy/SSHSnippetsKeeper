# Аудит датасета скриптов

Дата: 2026-10-28. Объём: 120 файлов (40 bash, 40 powershell, 40 cmd).

## 1. Итог

Жёстких нарушений требований ML: **0**. Полных дублей содержимого: **0**.

Найдено 13 тематических пересечений: 1 средней значимости и 12 низкой. Ни одно не является копией функционала: пересекаются предметная область или конечная цель, но набор действий и команд различается.

После первого прогона аудита `cmd/event_log_export_52.cmd` (дублировал `powershell/event_log_export_48.ps1`) заменён на `cmd/system_integrity_52.cmd` — проверку целостности системы через `sfc` и `dism`. Экспорт журналов событий теперь есть только в PowerShell.

## 2. Жёсткие проверки

| Проверка | bash | powershell | cmd | Результат |
|---|---|---|---|---|
| Длина 20–50 строк | 24–50 | 26–50 | 20–44 | OK |
| Комментарии (`#`, `REM`, `::`, `<# #>`) | 0 | 0 | 0 | OK |
| Wrapper-вызовы (`powershell`/`wsl` в CMD, `cmd /c`/`bash` в PS, `python` в bash) | 0 | 0 | 0 | OK |
| Заглушки, `...`, TODO/FIXME | 0 | 0 | 0 | OK |
| Не-ASCII символы | 0 | 0 | 0 | OK |
| CRLF | 0 | 0 | 0 | OK |
| Отсутствует завершающий перевод строки | 0 | 0 | 0 | OK |
| Одинаковые md5 | 0 | 0 | 0 | OK |
| Обязательный префикс (`#!/bin/bash` / `@echo off`) | 40/40 | — | 40/40 | OK |

Комментариями не считались: shebang `#!/bin/bash` (нужен для исполняемости, есть во всех 40 bash-файлах) и `${#ARRAY[@]}` в `apt_security_updates_31.sh` и `dns_zone_audit_35.sh` — это длина массива, а не комментарий. Строка `<none>` в `docker_image_audit_43.ps1` — реальный вывод `docker image ls`, а не заглушка.

## 3. Тематические пересечения

| # | Файлы | Что общего | Оценка |
|---|---|---|---|
| 1 | `bash/fail2ban_report_18.sh` ↔ `bash/ssh_fail_report_33.sh` | SSH-защита: баны через fail2ban-client против разбора auth.log | низкое: разные источники данных и действия (unban vs blocklist) |
| 2 | `bash/db_backup_03.sh` ↔ `bash/s3_dump_upload_32.sh` | PostgreSQL-дампы → S3 + чистка старых копий | среднее: совпадает конечная цель, но 03 делает pg_dump+sync, 32 упаковывает готовые дампы и проверяет head-object |
| 3 | `bash/log_rotate_02.sh` ↔ `bash/runner_cache_prune_36.sh` | удаление устаревших файлов по возрасту | низкое: логи с gzip/truncate против кэша CI с квотой по размеру |
| 4 | `bash/systemd_patch_30.sh` ↔ `bash/apt_security_updates_31.sh` | apt и security-обновления | низкое: 30 устанавливает обновления, 31 только отчёт и exit-код |
| 5 | `powershell/docker_image_audit_43.ps1` ↔ `bash/docker_cleanup_04.sh` | очистка Docker-образов | низкое: 43 инвентаризация и prune по возрасту, 04 чистка контейнеров и висячих образов |
| 6 | `powershell/smb_permissions_44.ps1` ↔ `cmd/share_audit_56.cmd` | аудит SMB-шар | низкое: ACL и риски против перечисления шар, сессий и openfiles |
| 7 | `powershell/gpo_compliance_49.ps1` ↔ `cmd/gpresult_audit_28.cmd` | аудит групповых политик | низкое: разбор GPO XML против RSoP-отчёта gpresult |
| 8 | `powershell/sql_backup_05.ps1` ↔ `cmd/sql_backup_verify_54.cmd` | резервное копирование SQL | низкое: создание бэкапа против RESTORE VERIFYONLY |
| 9 | `powershell/eventlog_errors_11.ps1` ↔ `powershell/event_log_export_48.ps1` | Get-WinEvent | низкое: анализ ошибок против выгрузки журналов |
| 10 | `cmd/iis_apppool_13.cmd` ↔ `cmd/iis_bindings_57.cmd` | IIS через appcmd | низкое: пулы приложений против сайтов и биндингов |
| 11 | `cmd/disk_report_05.cmd` ↔ `cmd/volume_health_58.cmd` | состояние дисков | низкое: свободное место и дефрагментация против fsutil volumeinfo и dirty bit |
| 12 | `powershell/ad_inactive_users_01.ps1` ↔ `powershell/ad_password_expiry_41.ps1` | гигиена учётных записей AD | низкое: неактивность против срока действия пароля |
| 13 | `powershell/net_adapter_09.ps1` ↔ `powershell/port_owner_audit_47.ps1` | сетевая диагностика Windows | низкое: адаптеры и DNS против слушающих портов |

Дубли внутри одного языка: не обнаружены. Максимальная Jaccard-близость по редким токенам среди пар — 0.24 (`iis_apppool_13` и `iis_bindings_57`), и она отражает общий `appcmd`, а не общий сценарий; следующие пары лежат в диапазоне 0.22–0.24.

Межъязыковые аналоги, существовавшие до первого аудита и не считающиеся нарушением: `log_rotate_02.sh`/`log_rotate_30.cmd`, `service_watchdog_10.sh`/`service_watchdog_04.ps1`, `ssl_cert_check_11.sh`/`cert_store_27.ps1`, `disk_report_05.cmd`/`disk_space_report_10.ps1`.

## 4. Инвентарь

### bash (40)

| Файл | Строк |
|---|---|
| `alert_webhook_40.sh` | 31 |
| `apt_security_updates_31.sh` | 29 |
| `ci_deploy_07.sh` | 37 |
| `cron_manager_20.sh` | 47 |
| `csv_merge_09.sh` | 31 |
| `db_backup_03.sh` | 33 |
| `disk_alert_08.sh` | 38 |
| `dns_zone_audit_35.sh` | 34 |
| `docker_cleanup_04.sh` | 40 |
| `encrypted_archive_28.sh` | 39 |
| `fail2ban_report_18.sh` | 41 |
| `git_prepush_hook_16.sh` | 36 |
| `haproxy_stats_26.sh` | 24 |
| `hw_inventory_29.sh` | 27 |
| `json_parse_06.sh` | 31 |
| `k8s_debug_21.sh` | 25 |
| `kafka_lag_check_37.sh` | 37 |
| `ldap_sync_22.sh` | 37 |
| `log_rotate_02.sh` | 33 |
| `lvm_snapshot_17.sh` | 37 |
| `mem_tune_24.sh` | 31 |
| `mysql_slow_summary_38.sh` | 43 |
| `net_monitor_01.sh` | 32 |
| `nftables_firewall_25.sh` | 39 |
| `nginx_log_top_13.sh` | 42 |
| `pg_replication_23.sh` | 31 |
| `postfix_queue_guard_34.sh` | 50 |
| `rabbitmq_watch_15.sh` | 37 |
| `redis_maintenance_27.sh` | 30 |
| `rsync_mirror_12.sh` | 40 |
| `runner_cache_prune_36.sh` | 39 |
| `s3_dump_upload_32.sh` | 34 |
| `service_watchdog_10.sh` | 34 |
| `smart_health_14.sh` | 35 |
| `ssh_fail_report_33.sh` | 29 |
| `ssl_cert_check_11.sh` | 31 |
| `systemd_patch_30.sh` | 33 |
| `template_render_19.sh` | 35 |
| `user_audit_05.sh` | 30 |
| `wireguard_peer_39.sh` | 36 |

### powershell (40)

| Файл | Строк |
|---|---|
| `ad_inactive_users_01.ps1` | 30 |
| `ad_password_expiry_41.ps1` | 41 |
| `bitlocker_status_19.ps1` | 26 |
| `cert_store_27.ps1` | 37 |
| `compress_reports_25.ps1` | 38 |
| `csv_dedup_30.ps1` | 41 |
| `csv_to_sql_21.ps1` | 43 |
| `dhcp_dns_audit_17.ps1` | 32 |
| `disk_space_report_10.ps1` | 30 |
| `docker_image_audit_43.ps1` | 50 |
| `dsc_drift_45.ps1` | 49 |
| `duplicate_files_28.ps1` | 38 |
| `event_log_export_48.ps1` | 46 |
| `eventlog_errors_11.ps1` | 30 |
| `exchange_mailbox_02.ps1` | 29 |
| `exchange_queue_23.ps1` | 31 |
| `farm_uptime_29.ps1` | 31 |
| `file_retention_07.ps1` | 40 |
| `git_release_16.ps1` | 39 |
| `gpo_compliance_49.ps1` | 49 |
| `hyperv_vms_14.ps1` | 33 |
| `iis_log_stats_12.ps1` | 38 |
| `json_api_pagination_42.ps1` | 49 |
| `local_groups_26.ps1` | 35 |
| `net_adapter_09.ps1` | 30 |
| `perf_counters_18.ps1` | 37 |
| `port_owner_audit_47.ps1` | 40 |
| `printer_inventory_15.ps1` | 26 |
| `registry_audit_06.ps1` | 30 |
| `rest_api_monitor_03.ps1` | 42 |
| `scheduled_tasks_08.ps1` | 28 |
| `service_dependency_map_50.ps1` | 47 |
| `service_watchdog_04.ps1` | 36 |
| `smb_permissions_44.ps1` | 41 |
| `software_inventory_20.ps1` | 27 |
| `sql_backup_05.ps1` | 37 |
| `vss_snapshot_46.ps1` | 48 |
| `wmi_services_24.ps1` | 27 |
| `wsus_patching_13.ps1` | 29 |
| `xml_config_22.ps1` | 41 |

### cmd (40)

| Файл | Строк |
|---|---|
| `ad_computer_cleanup_53.cmd` | 42 |
| `ci_build_60.cmd` | 40 |
| `cipher_secure_16.cmd` | 25 |
| `csv_parser_17.cmd` | 28 |
| `dated_backup_12.cmd` | 37 |
| `disk_report_05.cmd` | 25 |
| `diskpart_query_26.cmd` | 28 |
| `env_vars_15.cmd` | 27 |
| `firewall_rules_18.cmd` | 28 |
| `gpresult_audit_28.cmd` | 26 |
| `hosts_manager_21.cmd` | 32 |
| `iis_apppool_13.cmd` | 35 |
| `iis_bindings_57.cmd` | 31 |
| `log_grep_07.cmd` | 33 |
| `log_rotate_30.cmd` | 26 |
| `makecab_archive_23.cmd` | 33 |
| `mem_monitor_29.cmd` | 26 |
| `msi_deploy_11.cmd` | 27 |
| `net_diag_04.cmd` | 35 |
| `ntp_sync_59.cmd` | 34 |
| `printer_setup_14.cmd` | 28 |
| `process_killer_06.cmd` | 36 |
| `quota_report_19.cmd` | 26 |
| `rdp_sessions_22.cmd` | 25 |
| `registry_backup_02.cmd` | 35 |
| `robocopy_backup_03.cmd` | 37 |
| `routes_arp_27.cmd` | 32 |
| `schtasks_manager_08.cmd` | 36 |
| `service_manager_01.cmd` | 44 |
| `share_audit_56.cmd` | 32 |
| `software_reg_20.cmd` | 25 |
| `sql_backup_verify_54.cmd` | 38 |
| `sysinfo_report_10.cmd` | 22 |
| `system_integrity_52.cmd` | 44 |
| `update_client_25.cmd` | 32 |
| `usb_device_audit_55.cmd` | 26 |
| `user_mgmt_09.cmd` | 34 |
| `user_profiles_24.cmd` | 20 |
| `volume_health_58.cmd` | 33 |
| `wifi_profiles_51.cmd` | 35 |

## 5. Рекомендации

1. Если нужна строгая уникальность сценариев между языками, развести `docker_image_audit_43`/`docker_cleanup_04` и `smb_permissions_44`/`share_audit_56`.
2. Пару `db_backup_03`/`s3_dump_upload_32` стоит развести по акценту: оставить 32 только про верификацию загрузки и lifecycle, либо переписать 32 на другой объект (например, ротацию WAL-архива).
3. Остальные пересечения ниже порога «дубль»: для классификатора языков они полезны, так как дают одинаковую предметную область в разном синтаксисе.
4. Повторять проверки после любых правок: длина, комментарии, wrapper-вызовы, md5-дубли.

