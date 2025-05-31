#!/bin/bash

# 팰월드 RCON 재부팅 스크립트 (올바른 버전)
SERVER_PATH="/서버파일/위치한/경로/PalServer"
RCON_PASSWORD="RCON_PASSWORD"
LOG_FILE="/원하는/경로/PalServer_reboot.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

send_rcon() {
    local cmd="$1"
    log_msg "RCON 명령 전송: $cmd"
    
    result=$(python3 -c "
import socket, struct, sys
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(10)
    s.connect(('127.0.0.1', 25575))
    
    password = \"$RCON_PASSWORD\"
    auth = struct.pack('<iii', 10, 1, 3) + password.encode() + b'\x00\x00'
    s.send(auth)
    auth_response = s.recv(1024)
    
    if len(auth_response) >= 12:
        auth_id = struct.unpack('<i', auth_response[4:8])[0]
        if auth_id != 1:
            print('AUTH_FAILED')
            sys.exit(1)
    
    cmd = \"$cmd\"
    packet = struct.pack('<iii', len(cmd) + 10, 2, 2) + cmd.encode() + b'\x00\x00'
    s.send(packet)
    
    response = s.recv(4096)
    s.close()
    print('SUCCESS')
except Exception as e:
    print('ERROR:', str(e))
    sys.exit(1)
")
    
    if [[ "$result" == *"SUCCESS"* ]]; then
        return 0
    else
        log_msg "RCON 명령 실패: $result"
        return 1
    fi
}

test_rcon() {
    result=$(python3 -c "
import socket, struct, sys
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect(('127.0.0.1', 25575))
    
    password = \"$RCON_PASSWORD\"
    auth = struct.pack('<iii', 10, 1, 3) + password.encode() + b'\x00\x00'
    s.send(auth)
    response = s.recv(1024)
    
    if len(response) >= 12:
        auth_id = struct.unpack('<i', response[4:8])[0]
        if auth_id == 1:
            print('SUCCESS')
        else:
            print('AUTH_FAILED')
    else:
        print('INVALID_RESPONSE')
    s.close()
except Exception as e:
    print('ERROR:', str(e))
")
    echo "$result"
}

check_server_running() {
    PID=$(pgrep -f "PalServer")
    if [ -n "$PID" ]; then
        log_msg "서버 실행 중 (PID: $PID)"
        return 0
    else
        log_msg "서버가 실행되지 않음"
        return 1
    fi
}

log_msg "=== 팰월드 서버 재부팅 시작 ==="

# 서버 상태 확인
if ! check_server_running; then
    log_msg "서버가 실행되지 않아 재부팅을 중단합니다."
    exit 1
fi

# RCON 연결 테스트
log_msg "RCON 연결 테스트 중..."
rcon_test=$(test_rcon)
log_msg "RCON 테스트 결과: $rcon_test"

if [[ "$rcon_test" != "SUCCESS" ]]; then
    log_msg "RCON 연결 실패. 스크립트 종료."
    exit 1
fi

# 5분 경고
log_msg "5분 후 재부팅 알림 전송"
send_rcon "Broadcast Server will restart in 5 minutes!"

# 4분 대기
sleep 240

# 저장 및 1분 경고
log_msg "게임 저장 및 1분 경고"
send_rcon "Save"
send_rcon "Broadcast Server restarting in 1 minute! LOGOUT NOW!"

# 50초 대기
sleep 50

# 10초 카운트다운
for i in {10..1}; do
    send_rcon "Broadcast Restart in $i seconds!"
    sleep 1
done

# 서버 종료
log_msg "서버 종료 명령 전송"
send_rcon "Shutdown 60 Server restarting now!"

# 종료 대기
sleep 70

# 강제 종료 (필요시)
PID=$(pgrep -f "PalServer")
if [ -n "$PID" ]; then
    log_msg "서버가 아직 실행 중 - 강제 종료: $PID"
    kill -TERM $PID
    sleep 10
    
    if pgrep -f "PalServer" > /dev/null; then
        log_msg "TERM 신호로 종료되지 않음 - KILL 신호 사용"
        kill -KILL $PID
        sleep 5
    fi
fi

# 완전히 종료될 때까지 대기
while pgrep -f "PalServer" > /dev/null; do
    log_msg "서버 종료 대기 중..."
    sleep 2
done

log_msg "서버 종료 완료"

# 서버 재시작
log_msg "서버 재시작"
cd "$SERVER_PATH"
nohup ./PalServer.sh > "$LOG_FILE.server" 2>&1 &

# 서버 시작 확인
for i in {1..30}; do
    if pgrep -f "PalServer" > /dev/null; then
        log_msg "서버 시작 확인됨"
        break
    fi
    log_msg "서버 시작 대기 중... ($i/30)"
    sleep 2
done

log_msg "=== 재부팅 완료 ==="