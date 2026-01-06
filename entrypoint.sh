#!/bin/sh

umask ${UMASK}

if [ "$1" = "version" ]; then
  ./openlist version
else
  # 只有在使用本地存储模式时才检查 data 目录权限
  # Only check data directory permissions when using local storage mode
  if [ "$USE_DATABASE" != "true" ]; then
    # 如果 data 目录不存在，尝试创建它
    # If data directory doesn't exist, try to create it
    if [ ! -d ./data ]; then
      mkdir -p ./data 2>/dev/null || {
        cat <<EOF
Warning: Unable to create ./data directory. Attempting to run in memory-only mode.
警告：无法创建 ./data 目录。尝试以仅内存模式运行。
If you want to persist data, please set up a database using environment variables:
如果您想持久化数据，请使用环境变量设置数据库：
  - DATABASE_TYPE (mysql, postgres, sqlite, etc.)
  - DATABASE_URL or DATABASE_HOST, DATABASE_PORT, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD
EOF
      }
    fi
    
    # 检查当前用户是否有当前目录的写和执行权限
    # Check if current user has write and execute permissions for current directory
    if [ -d ./data ]; then
      if ! [ -w ./data ] || ! [ -x ./data ]; then
        cat <<EOF
Error: Current user does not have write and/or execute permissions for the ./data directory: $(pwd)/data
Please either:
  1. Fix permissions for the ./data directory
  2. Set USE_DATABASE=true and configure database connection via environment variables
错误：当前用户没有 ./data 目录（$(pwd)/data）的写和/或执行权限。
请选择以下方案之一：
  1. 修复 ./data 目录的权限
  2. 设置 USE_DATABASE=true 并通过环境变量配置数据库连接
For more information, visit: https://doc.oplist.org/guide/installation/docker
Exiting...
EOF
        exit 1
      fi
    fi
  else
    echo "Running in database mode (USE_DATABASE=true)"
    echo "以数据库模式运行 (USE_DATABASE=true)"
    
    # 验证必要的数据库环境变量是否设置
    # Validate that necessary database environment variables are set
    if [ -z "$DATABASE_URL" ] && [ -z "$DATABASE_HOST" ]; then
      cat <<EOF
Error: Database mode is enabled but no database connection is configured.
Please set one of the following:
  - DATABASE_URL (full connection string)
  - DATABASE_HOST, DATABASE_PORT, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD
错误：已启用数据库模式但未配置数据库连接。
请设置以下环境变量之一：
  - DATABASE_URL（完整连接字符串）
  - DATABASE_HOST, DATABASE_PORT, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD
Exiting...
EOF
      exit 1
    fi
  fi

  # Define the target directory path for aria2 service
  ARIA2_DIR="/opt/service/start/aria2"
  if [ "$RUN_ARIA2" = "true" ]; then
    # If aria2 should run and target directory doesn't exist, copy it
    if [ ! -d "$ARIA2_DIR" ]; then
      mkdir -p "$ARIA2_DIR"
      cp -r /opt/service/stop/aria2/* "$ARIA2_DIR" 2>/dev/null
    fi
    runsvdir /opt/service/start &
  else
    # If aria2 should NOT run and target directory exists, remove it
    if [ -d "$ARIA2_DIR" ]; then
      rm -rf "$ARIA2_DIR"
    fi
  fi
  
  exec ./openlist server --no-prefix
fi
