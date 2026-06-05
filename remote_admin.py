import os
import sys
import socket
import threading
import json
import hashlib
import ssl
import subprocess
import time
from datetime import datetime

# --------------------------------------------------------
# REMOTE ADMIN SERVER - AUTHORIZED ACCESS ONLY
# --------------------------------------------------------
# Transparent remote administration tool. Requires 
# authentication. Encrypts traffic. Logs all sessions.
# --------------------------------------------------------

CONFIG = {
    "port": 4443,
    "password_hash": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8",  # "password"
    "log_file": "remote_admin.log"
}

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def log_event(event):
    timestamp = datetime.utcnow().isoformat()
    with open(CONFIG['log_file'], 'a') as f:
        f.write(f"[{timestamp}] {event}\n")

def authenticate(conn):
    try:
        challenge = os.urandom(16).hex()
        conn.sendall(f"AUTH_CHALLENGE:{challenge}\n".encode())
        response = conn.recv(1024).decode().strip()
        expected = hash_password(CONFIG['password_hash'] + challenge)
        
        if response == expected:
            conn.sendall(b"AUTH_SUCCESS\n")
            log_event(f"AUTH_SUCCESS from {conn.getpeername()}")
            return True
        else:
            conn.sendall(b"AUTH_FAILURE\n")
            log_event(f"AUTH_FAILURE from {conn.getpeername()}")
            return False
    except Exception as e:
        log_event(f"AUTH_ERROR: {e}")
        return False

def execute_command(command):
    blocked = ['rm -rf', 'del /', 'mkfs', 'dd if=', 'passwd', 'shadow', 
               'sudo', 'su ', 'chmod 777', ':(){:|:&};:', 'format ']
    
    cmd_lower = command.lower()
    for b in blocked:
        if b in cmd_lower:
            return {
                "status": "BLOCKED",
                "output": "Command violates safety policy.",
                "exit_code": -1
            }
    
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        return {
            "status": "SUCCESS",
            "output": result.stdout[:8192],
            "error": result.stderr[:2048],
            "exit_code": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {"status": "TIMEOUT", "output": "Command timed out.", "exit_code": -1}
    except Exception as e:
        return {"status": "ERROR", "output": str(e), "exit_code": -1}

def handle_client(conn, addr):
    if not authenticate(conn):
        conn.close()
        return
    
    conn.sendall(b"REMOTE_ADMIN_v1.0_READY\n")
    
    while True:
        try:
            data = conn.recv(4096)
            if not data:
                break
            
            command = data.decode().strip()
            if command.lower() in ['exit', 'quit']:
                conn.sendall(b"DISCONNECTING\n")
                break
            
            log_event(f"COMMAND from {addr}: {command}")
            result = execute_command(command)
            response = json.dumps(result) + "\n"
            conn.sendall(response.encode())
            
        except (ConnectionResetError, socket.timeout):
            break
        except Exception as e:
            log_event(f"SESSION_ERROR: {e}")
            break
    
    log_event(f"DISCONNECT from {addr}")
    conn.close()

def generate_self_signed_cert():
    cert_file = "admin_cert.pem"
    key_file = "admin_key.pem"
    
    if not os.path.exists(cert_file) or not os.path.exists(key_file):
        try:
            subprocess.run([
                'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
                '-keyout', key_file, '-out', cert_file,
                '-days', '365', '-nodes', '-subj',
                '/CN=RemoteAdmin/O=AdminTools/C=US'
            ], capture_output=True, check=True)
            return True
        except Exception:
            return False
    return True

def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', CONFIG['port']))
    server.listen(5)
    
    if generate_self_signed_cert():
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain('admin_cert.pem', 'admin_key.pem')
        server = context.wrap_socket(server, server_side=True)
        print(f"\033[92m[+] SSL enabled. Connection encrypted.\033[0m")
    else:
        print(f"\033[91m[!] SSL failed. Running unencrypted.\033[0m")
    
    print(f"\033[92m[+] Remote Admin listening on port {CONFIG['port']}\033[0m")
    print(f"\033[93m[!] Change default password before deployment.\033[0m")
    log_event("SERVER_STARTED")
    
    while True:
        try:
            conn, addr = server.accept()
            log_event(f"CONNECTION from {addr}")
            print(f"\033[96m[*] Connection from {addr}\033[0m")
            
            client_thread = threading.Thread(
                target=handle_client,
                args=(conn, addr),
                daemon=True
            )
            client_thread.start()
        except KeyboardInterrupt:
            break
        except Exception as e:
            log_event(f"ACCEPT_ERROR: {e}")
    
    server.close()

def print_banner():
    print("\033[91m  _   _ _   _ _   _ _____  ____   ____  _   _    \033[0m")
    print("\033[91m | \\ | | | | | \\ | |_   _|/ ___| / ___|| | | |   \033[0m")
    print("\033[91m |  \\| | | | |  \\| | | |  \\___ \\| |    | |_| |   \033[0m")
    print("\033[91m | |\\  | |_| | |\\  | | |   ___) | |___ |  _  |   \033[0m")
    print("\033[91m |_| \\_|\\___/|_| \\_| |_|  |____/ \\____||_| |_|   \033[0m")
    print("\033[91m  _       _                           \033[0m")
    print("\033[91m | |     | |                          \033[0m")
    print("\033[91m | |_ ___| | ___ _ __ ___   __ _ _ __ \033[0m")
    print("\033[91m | __/ _ \\ |/ _ \\ '_ ` _ \\ / _` | '__|\033[0m")
    print("\033[91m | ||  __/ |  __/ | | | | | (_| | |   \033[0m")
    print("\033[91m  \\__\\___|_|\\___|_| |_| |_|\\__,_|_|   \033[0m")
    print()
    print("\033[91m      [01] START SERVER\033[0m")
    print("\033[91m      [02] CHANGE PASSWORD\033[0m")
    print("\033[91m      [03] VIEW LOGS\033[0m")
    print("\033[91m      [04] EXIT\033[0m")
    print()

def change_password():
    new_pass = input("\033[91m[?] New password: \033[0m")
    if new_pass:
        CONFIG['password_hash'] = hash_password(new_pass)
        print(f"\033[92m[+] Password updated. Hash: {CONFIG['password_hash']}\033[0m")
        print("\033[93m[!] Update the CONFIG dictionary to persist.\033[0m")
    else:
        print("\033[91m[!] Password cannot be empty.\033[0m")

def view_logs():
    if os.path.exists(CONFIG['log_file']):
        with open(CONFIG['log_file'], 'r') as f:
            print(f.read())
    else:
        print("\033[93m[!] No logs found.\033[0m")

if __name__ == "__main__":
    print("\033[93m[!] For authorized system administration only.\033[0m")
    print("\033[93m[!] Unauthorized access is illegal.\033[0m\n")
    
    while True:
        print_banner()
        choice = input("\033[91m[?] Select option: \033[0m").strip()
        
        if choice == '1':
            start_server()
        elif choice == '2':
            change_password()
        elif choice == '3':
            view_logs()
        elif choice == '4':
            print("Exiting...")
            sys.exit(0)