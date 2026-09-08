"""Servidor simulado de la API refaNet para validar tool/api_full_test.py sin red.

Implementa las 56 rutas del contrato con respuestas plausibles y estado en
memoria. No sustituye al servidor real: sirve para comprobar que la prueba
total recorre el ciclo completo y para desarrollar sin conexión.

    python tool/api_mock_server.py 8765
    python tool/api_full_test.py --base-url=http://127.0.0.1:8765 \
        --phone=+5215500000000 --otp=123456 --create-yonke

El OTP aceptado por el simulador es siempre 123456.
"""
import json, re, uuid, base64, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

def jwt(sub, extra=None):
    h = base64.urlsafe_b64encode(b'{"alg":"none"}').decode().rstrip("=")
    p = {"sub": sub, "exp": 9999999999}
    p.update(extra or {})
    b = base64.urlsafe_b64encode(json.dumps(p).encode()).decode().rstrip("=")
    return f"{h}.{b}.sig"

CLIENT = "cliente-1"
YONKE = str(uuid.uuid4())
STATE = {"requests": {}, "images": {}, "assign": {}, "quotes": {}, "orders": {}, "msgs": {}}

def env(data, ok=True, msg="ok"):
    return {"success": ok, "message": msg, "data": data, "statusCode": 200 if ok else 400, "errors": None}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def send(self, code, body=None, ctype="application/json"):
        raw = b"" if body is None else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        if "json" in (self.headers.get("Content-Type") or ""):
            try: return json.loads(raw)
            except Exception: return None
        return raw

    def auth(self):
        a = self.headers.get("Authorization") or ""
        return a.replace("Bearer ", "") if a.startswith("Bearer ") else None

    def route(self, m):
        path, _, qs = self.path.partition("?")
        q = dict(p.split("=", 1) for p in qs.split("&") if "=" in p)
        b = self.body()
        tok = self.auth()
        S = STATE
        g = lambda: str(uuid.uuid4())

        def r(pat):
            mm = re.fullmatch(pat, path); return (mm.groups() or True) if mm else None

        # públicos
        if m == "POST" and path == "/api/ClienteAuth/solicitar-otp": return self.send(200, env(None, msg="OTP enviado"))
        if m == "POST" and path == "/api/ClienteAuth/verificar-otp":
            if b.get("codigo") != "123456": return self.send(400, env(None, False, "Código inválido"))
            return self.send(200, env({"token": jwt(CLIENT), "expiresIn": 3600}))
        if m == "POST" and path == "/api/YonkeAuth/login":
            return self.send(200, env({"accessToken": jwt("yonke-user", {"yonkeGuidId": YONKE}), "yonkeGuidId": YONKE}))
        if m == "POST" and path == "/api/Yonkes":
            return self.send(200, env({"guidId": YONKE, "nombre": "Yonke prueba"}))
        if m == "GET" and path == "/api/Utilerias/entidades": return self.send(200, env([{"id": 1, "entidad": "Jalisco"}]))
        if r(r"/api/Utilerias/entidad/\d+/ciudades"): return self.send(200, env([{"id": 10, "ciudad": "Guadalajara"}, {"id": 11, "ciudad": "Zapopan"}]))
        if r(r"/api/Utilerias/entidad/\d+"): return self.send(200, env({"id": 1, "entidad": "Jalisco"}))
        if r(r"/api/Utilerias/ciudad/\d+"): return self.send(200, env({"id": 10, "ciudad": "Guadalajara"}))
        if path == "/api/Utilerias/marcas": return self.send(200, env([{"id": 3, "marca": "Nissan"}]))
        if r(r"/api/Utilerias/marca/\d+"): return self.send(200, env({"id": 3, "marca": "Nissan"}))
        if path == "/api/Utilerias/modelos": return self.send(200, env([{"id": 7, "modelo": "Sentra"}]))
        if r(r"/api/Utilerias/modelo/\d+"): return self.send(200, env({"id": 7, "modelo": "Sentra"}))
        if path == "/api/Pagos/stripe/webhook": return self.send(400, {"error": "missing signature"})

        if not tok: return self.send(401)

        if path == "/api/Yonkes/byPage": return self.send(200, env({"items": [{"guidId": YONKE, "nombre": "Yonke prueba"}], "total": 1}))
        if path == "/api/ClienteAuth/registrar-dispositivo" or path == "/api/YonkesDispositivos": return self.send(200, env(None))
        if path == "/api/DashboardSuscriptores/resumen": return self.send(200, env({"solicitudes": len(S["requests"]), "cotizaciones": len(S["quotes"])}))
        if path == "/api/DashboardSuscriptores/mis-solicitudes":
            claims = json.loads(base64.urlsafe_b64decode(tok.split(".")[1] + "==="))
            if claims["sub"] == CLIENT:
                return self.send(200, env({"items": list(S["requests"].values()), "page": 1}))
            rows = [{"guidId": k, "solicitudGuidId": v, "yonkeGuidId": YONKE, "estatusId": 1, "solicitudes": S["requests"][v]} for k, v in S["assign"].items()]
            return self.send(200, env({"items": rows}))
        if path == "/api/DashboardSuscriptores/mis-cotizaciones": return self.send(200, env(list(S["quotes"].values())))
        if path == "/api/DashboardSuscriptores/mi-solicitud-reciente":
            vals = list(S["requests"].values()); return self.send(200, env(vals[-1] if vals else None))
        if path == "/api/Solicitudes/AllPaged": return self.send(200, env({"items": list(S["requests"].values())}))
        if m == "POST" and path == "/api/Solicitudes":
            gid = g(); S["requests"][gid] = {"guidId": gid, "marca": "Nissan", "modelo": "Sentra", "estatusSolicitud": "Abierta", "piezaBuscada": b["piezaBuscada"], "totalCotizaciones": 0, "ciudades": b.get("ciudadesIds", [])}
            return self.send(200, env({"guidId": gid}))
        x = r(r"/api/Solicitudes/([^/]+)")
        if x:
            if m == "GET": return self.send(200, env(S["requests"].get(x[0])))
            if m == "DELETE": S["requests"].pop(x[0], None); return self.send(200, env("cancelada"))
        if path == "/api/SolicitudCiudades/existe": return self.send(200, env(True))
        x = r(r"/api/SolicitudCiudades/([^/]+)/ciudades")
        if x:
            if m == "GET": return self.send(200, env([{"ciudadId": 10}, {"ciudadId": 11}]))
            return self.send(200, env(None))
        if r(r"/api/SolicitudCiudades/([^/]+)/ciudad/\d+"): return self.send(200, env(None))
        x = r(r"/api/SolicitudesImagenes/solicitud/([^/]+)")
        if x: return self.send(200, env([{"guidId": k, "urlImagen": "https://blob/" + k} for k, v in S["images"].items() if v == x[0]]))
        x = r(r"/api/SolicitudesImagenes/([^/]+)")
        if x:
            if m == "POST":
                if b"image/png" not in b: return self.send(400, env(None, False, "sin imágenes"))
                for _ in range(b.count(b"image/png")): S["images"][g()] = x[0]
                return self.send(200, env(None))
            if m == "GET": return self.send(200, env({"guidId": x[0], "urlImagen": "https://blob/" + x[0]}))
            if m == "DELETE": S["images"].pop(x[0], None); return self.send(200, env(None))
        x = r(r"/api/SolicitudYonkes/([^/]+)/enviar")
        if x: S["assign"][g()] = x[0]; return self.send(200, env({"enviados": 1}))
        if r(r"/api/SolicitudYonkes/([^/]+)/vista"): return self.send(200, env(None))
        x = r(r"/api/Yonkes/([^/]+)")
        if x and m == "GET": return self.send(200, env({"guidId": YONKE, "nombre": "Yonke prueba", "correo": "a@b.c", "ciudadId": 10}))
        if r(r"/api/YonkesCoberturas/guid/([^/]+)"): return self.send(200, env([{"ciudadId": 10, "activo": True}]))
        if path == "/api/YonkesCoberturas": return self.send(200, env(None))
        if r(r"/api/Yonkes/updateInfo/byGuidId/([^/]+)"): return self.send(200, env(None))
        if path == "/api/Yonkes/ActualizarLogo": return self.send(200, env(None))
        if r(r"/api/Yonkes/baja/byGuidId/([^/]+)"): return self.send(200, env(None))
        if r(r"/api/YonkesCalificaciones/([^/]+)"): return self.send(200, env([]))
        if path == "/api/YonkesCalificaciones": return self.send(200, env(None))
        if m == "POST" and path == "/api/CotizacionYonke":
            qid = g(); S["quotes"][qid] = {"guidId": qid, "precio": 1500.5, "disponible": True, "activo": True, "solicitudYonkeGuidId": q.get("solicitudYonkeGuidId"), "solicitudYonkes": {"solicitudGuidId": "x", "yonkeGuidId": YONKE, "yonkes": {"nombre": "Yonke prueba"}}}
            return self.send(200, env({"guidId": qid}))
        x = r(r"/api/CotizacionYonke/([^/]+)")
        if x:
            if m == "GET": return self.send(200, env(S["quotes"].get(x[0])))
            if m == "PUT": return self.send(200, env("actualizada"))
        if m == "POST" and path == "/api/SolicitudCotizacionMensajes":
            claims = json.loads(base64.urlsafe_b64decode(tok.split(".")[1] + "==="))
            S["msgs"].setdefault(b["solicitudCotizacionGuidId"], []).append({"guidId": g(), "mensaje": b["mensaje"], "tipoRemitenteId": 1 if claims["sub"] == CLIENT else 2, "usuarioId": claims["sub"], "fechaCreacion": "2026-09-08T00:00:00Z", "leido": False})
            return self.send(200, env(None))
        x = r(r"/api/SolicitudCotizacionMensajes/([^/]+)/no-leidos")
        if x: return self.send(200, env(1))
        x = r(r"/api/SolicitudCotizacionMensajes/([^/]+)/leer")
        if x: return self.send(200, env(None))
        x = r(r"/api/SolicitudCotizacionMensajes/([^/]+)")
        if x: return self.send(200, env(S["msgs"].get(x[0], [])))
        if m == "POST" and path == "/api/Orden":
            oid = g(); S["orders"][oid] = {"guidId": oid, "cotizacionGuidId": b["cotizacionGuidId"], "estatus": "Creada"}
            return self.send(200, env({"guidId": oid}))
        x = r(r"/api/Orden/cotizacion/([^/]+)")
        if x: return self.send(200, env(next((o for o in S["orders"].values() if o["cotizacionGuidId"] == x[0]), None)))
        x = r(r"/api/Orden/([^/]+)/cancelar")
        if x: return self.send(200, env(None))
        x = r(r"/api/Orden/([^/]+)")
        if x: return self.send(200, env(S["orders"].get(x[0])))
        x = r(r"/api/Pagos/checkout/([^/]+)")
        if x: return self.send(200, env({"url": "https://checkout.stripe.com/c/pay/cs_test_123", "sessionId": "cs_test_123"}))
        if r(r"/api/Pagos/resultado/([^/]+)"): return self.send(200, env({"status": "open"}))
        if path == "/pago/exitoso": return self.send(200, "<html>ok</html>", "text/html")
        self.send(404, env(None, False, "no encontrado"))

    def do_GET(self): self.route("GET")
    def do_POST(self): self.route("POST")
    def do_PUT(self): self.route("PUT")
    def do_DELETE(self): self.route("DELETE")

if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
